"""Immutable research dataset index: exclusions, duplicate collapse and grouped splits.

Raw image paths are resolved only through DATASET_PATH. This module never copies,
renames, deletes, augments or rewrites images, and exports no camera/GPS/private paths.
"""

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
from typing import Annotated, Literal

from maizedoctor_preprocessing import PreprocessingConfig
from pydantic import BaseModel, ConfigDict, Field, JsonValue, TypeAdapter, field_validator

from configuration import load_dataset_path
from dataset_inventory import file_digest
from dataset_review import validate_destination

Digest = Annotated[str, Field(pattern=r"^[a-f0-9]{64}$")]
SplitName = Literal["train", "validation", "test"]
CLASS_LABELS = ("Common_Rust", "Gray_Leaf_Spot", "Healthy", "Northern_Corn_Leaf_Blight")
SPLIT_NAMES: tuple[SplitName, ...] = ("train", "validation", "test")
SEED = 20261007
_PROJECT = Path(__file__).resolve().parent
_REPOSITORY = _PROJECT.parent
_REVIEW = _REPOSITORY / ".cache/dataset-review/phase95-20261007"


class DatasetPreparationError(ValueError):
    """Invalid or changed data prevents a reproducible training index."""


class _FrozenModel(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid", strict=True)


class _InputModel(BaseModel):
    model_config = ConfigDict(frozen=True, extra="ignore", strict=True)


def _relative_path(value: str) -> str:
    path = PurePosixPath(value)
    if (
        not value
        or path.is_absolute()
        or "\\" in value
        or any(part in {"..", "."} or ":" in part for part in value.split("/"))
        or path.as_posix() != value
    ):
        raise DatasetPreparationError("Dataset members must have safe relative paths.")
    return value


class ClassDefinition(_FrozenModel):
    label: str
    index: int


class SourceReference(_FrozenModel):
    dataset_version_id: str
    variant: str
    source_class: str
    original_name: str
    declared_origin: bool


class SourceProvenance(_FrozenModel):
    references: tuple[SourceReference, ...]
    original_ids: tuple[str, ...]
    original_uuids: tuple[str, ...]


class SampleRecord(_FrozenModel):
    sample_id: Digest
    content_hash: Digest
    pixel_hash: Digest | None
    label: str
    class_index: int
    relative_path: str
    group_id: Digest
    duplicate_paths: tuple[str, ...]
    provenance: SourceProvenance

    _path = field_validator("relative_path")(_relative_path)


class ExclusionRecord(_FrozenModel):
    relative_path: str
    content_hash: Digest
    label: str
    reason_codes: tuple[str, ...]
    family_id: str | None

    _path = field_validator("relative_path")(_relative_path)


class SourceFile(_FrozenModel):
    relative_path: str
    content_hash: Digest
    size_bytes: int
    disposition: Literal["eligible", "duplicate", "excluded"]
    sample_id: Digest | None

    _path = field_validator("relative_path")(_relative_path)


class SplitDefinition(_FrozenModel):
    train: tuple[str, ...]
    validation: tuple[str, ...]
    test: tuple[str, ...]

    def as_mapping(self) -> dict[SplitName, tuple[str, ...]]:
        return {"train": self.train, "validation": self.validation, "test": self.test}


class DatasetManifest(_FrozenModel):
    schema_version: Literal[1] = 1
    version: str
    fingerprint: Digest
    classes: tuple[ClassDefinition, ...]
    eligible: tuple[SampleRecord, ...]
    excluded: tuple[ExclusionRecord, ...]
    source_inventory: tuple[SourceFile, ...]
    splits: SplitDefinition
    split_seed: int
    split_ratios: tuple[float, float, float]
    preprocessing_config: dict[str, JsonValue]
    preprocessing_hash: Digest
    input_hashes: dict[str, Digest]
    research_policy: dict[str, JsonValue]
    counts: dict[str, int]

    def rows_for_split(self, split: SplitName) -> tuple[SampleRecord, ...]:
        by_id = {row.sample_id: row for row in self.eligible}
        return tuple(by_id[sample_id] for sample_id in self.splits.as_mapping()[split])

    def load_preprocessing(self) -> PreprocessingConfig:
        """Use strict JSON parsing so configuration tuples survive JSON round trips."""
        return PreprocessingConfig.model_validate_json(
            json.dumps(self.preprocessing_config, allow_nan=False)
        )


class _InventoryRecord(_InputModel):
    relative_path: str
    label: str
    split: str | None
    size_bytes: int
    sha256: Digest
    mode: str | None
    frames: int | None
    pixel_hash: Digest | None
    metadata_keys: tuple[str, ...]
    preprocessing: dict[str, JsonValue]

    _path = field_validator("relative_path")(_relative_path)


class _SourceMember(_InputModel):
    source_dataset_version_id: str
    archive_name: str
    variant: str
    original_name: str
    original_uuid: str
    source_class: str


class _LinkedFile(_InputModel):
    relative_path: str
    label: str
    sha256: Digest
    archive_origin: str
    matching_source_members: tuple[_SourceMember, ...]
    recovered_original_uuids: tuple[str, ...]
    recovered_original_ids: tuple[str, ...]


class _Linkage(_InputModel):
    inventory_complete: bool
    files: tuple[_LinkedFile, ...]


class _SourceIndex(_InputModel):
    by_sha256: dict[str, tuple[_SourceMember, ...]]


class _InvalidInput(_FrozenModel):
    content_hash: Digest
    reason_code: str


class _ConflictFamily(_FrozenModel):
    family_id: str
    content_hashes: tuple[Digest, ...]
    reason_code: Literal["CONTRADICTORY_LABEL_FAMILY"]


class _ConfirmedEdge(_FrozenModel):
    first_hash: Digest
    second_hash: Digest
    kind: Literal["VISUALLY_CONFIRMED_NEAR", "VISUALLY_CONFIRMED_ROTATION"]


class _Evidence(_InputModel):
    schema_version: Literal[1]
    input_hashes: dict[str, Digest]
    invalid_inputs: tuple[_InvalidInput, ...]
    conflicting_families: tuple[_ConflictFamily, ...]
    confirmed_edges: tuple[_ConfirmedEdge, ...]


class _Groups:
    """Union only verified identities/content; never device IDs or timestamps."""

    def __init__(self, values: set[str]) -> None:
        self.parent = {value: value for value in values}

    def find(self, value: str) -> str:
        root = value
        while self.parent[root] != root:
            root = self.parent[root]
        while self.parent[value] != value:
            parent = self.parent[value]
            self.parent[value] = root
            value = parent
        return root

    def join(self, first: str, second: str) -> None:
        a, b = self.find(first), self.find(second)
        if a != b:
            self.parent[max(a, b)] = min(a, b)


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    return hashlib.sha256(encoded).hexdigest()


def _read_object(path: Path) -> dict[str, JsonValue]:
    return TypeAdapter(dict[str, JsonValue]).validate_json(path.read_bytes())


def _source_path(root: Path, relative: str) -> Path:
    _relative_path(relative)
    path = (root / relative).resolve(strict=True)
    if root not in path.parents or not path.is_file():
        raise DatasetPreparationError("Dataset member is outside the configured directory.")
    return path


def _verify_source_files(root: Path, files: tuple[SourceFile, ...]) -> None:
    paths = {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()}
    if paths != {file.relative_path for file in files}:
        raise DatasetPreparationError("Dataset file membership differs from the pinned inventory.")
    for file in files:
        path = _source_path(root, file.relative_path)
        before = path.stat()
        digest = file_digest(path)
        after = path.stat()
        if (
            digest != file.content_hash
            or before.st_size != file.size_bytes
            or (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns)
        ):
            raise DatasetPreparationError("Dataset contents differ from the pinned inventory.")


def _validate_manifest(manifest: DatasetManifest) -> None:
    if (
        canonical_hash(manifest.model_dump(mode="json", exclude={"fingerprint"}))
        != manifest.fingerprint
    ):
        raise DatasetPreparationError("Dataset manifest fingerprint mismatch.")
    if tuple((c.label, c.index) for c in manifest.classes) != tuple(enumerate_classes()):
        raise DatasetPreparationError("The literal label/index mapping must remain fixed.")
    config = manifest.load_preprocessing()
    if config.fingerprint != manifest.preprocessing_hash or config.segmentation.mode != "disabled":
        raise DatasetPreparationError("Dataset preprocessing configuration mismatch.")
    if manifest.split_seed != SEED or manifest.split_ratios != (0.7, 0.15, 0.15):
        raise DatasetPreparationError("The approved split seed and ratios must remain fixed.")
    if (
        manifest.research_policy.get("raw_image_redistribution") is not False
        or manifest.research_policy.get("commercial_clearance") is not False
    ):
        raise DatasetPreparationError("Research/nonredistribution policy is required.")
    by_id = {row.sample_id: row for row in manifest.eligible}
    if len(by_id) != len(manifest.eligible):
        raise DatasetPreparationError("Eligible sample identifiers must be unique.")
    source_by_path = {file.relative_path: file for file in manifest.source_inventory}
    if len(source_by_path) != len(manifest.source_inventory):
        raise DatasetPreparationError("Source inventory paths must be unique.")
    class_map = dict(enumerate_classes())
    grouped_split: dict[str, SplitName] = {}
    assigned: set[str] = set()
    for split, sample_ids in manifest.splits.as_mapping().items():
        if not sample_ids:
            raise DatasetPreparationError("Every split must contain eligible samples.")
        for sample_id in sample_ids:
            if sample_id in assigned or sample_id not in by_id:
                raise DatasetPreparationError("Splits overlap or reference an unknown sample.")
            assigned.add(sample_id)
            row = by_id[sample_id]
            previous = grouped_split.setdefault(row.group_id, split)
            if previous != split:
                raise DatasetPreparationError("Related source groups cross split boundaries.")
    if assigned != set(by_id):
        raise DatasetPreparationError("Every eligible sample must be assigned exactly once.")
    eligible_paths: set[str] = set()
    for row in manifest.eligible:
        if row.sample_id != row.content_hash or class_map.get(row.label) != row.class_index:
            raise DatasetPreparationError("Sample content identity or class index mismatch.")
        for path in (row.relative_path, *row.duplicate_paths):
            _relative_path(path)
            if PurePosixPath(path).parts[0] != row.label:
                raise DatasetPreparationError(
                    "Sample label differs from its literal source directory."
                )
            if path in eligible_paths or path not in source_by_path:
                raise DatasetPreparationError("Eligible paths are duplicated or unindexed.")
            eligible_paths.add(path)
            source = source_by_path[path]
            expected = "eligible" if path == row.relative_path else "duplicate"
            if source.sample_id != row.sample_id or source.disposition != expected:
                raise DatasetPreparationError("Source disposition does not match eligibility.")
            if expected == "eligible" and source.content_hash != row.content_hash:
                raise DatasetPreparationError("Canonical sample hash does not match source.")
    excluded_paths = {row.relative_path for row in manifest.excluded}
    if len(excluded_paths) != len(manifest.excluded) or eligible_paths & excluded_paths:
        raise DatasetPreparationError("Exclusions overlap eligible members.")
    if eligible_paths | excluded_paths != set(source_by_path):
        raise DatasetPreparationError("Every source path requires an explicit disposition.")
    for excluded_row in manifest.excluded:
        source = source_by_path[excluded_row.relative_path]
        if (
            not excluded_row.reason_codes
            or PurePosixPath(excluded_row.relative_path).parts[0] != excluded_row.label
            or source.disposition != "excluded"
            or source.sample_id is not None
            or source.content_hash != excluded_row.content_hash
        ):
            raise DatasetPreparationError("Exclusions require matching hashes and reason codes.")
    expected_counts: dict[str, int] = {
        "source_files": len(manifest.source_inventory),
        "source_unique_byte_contents": len(
            {file.content_hash for file in manifest.source_inventory}
        ),
        "excluded_files": len(manifest.excluded),
        "excluded_unique_contents": len({entry.content_hash for entry in manifest.excluded}),
        "eligible_unique_samples": len(manifest.eligible),
        "duplicate_aliases": sum(len(entry.duplicate_paths) for entry in manifest.eligible),
        "eligible_groups": len({entry.group_id for entry in manifest.eligible}),
        **{name: len(ids) for name, ids in manifest.splits.as_mapping().items()},
    }
    if manifest.counts != expected_counts:
        raise DatasetPreparationError("Manifest counts differ from indexed dispositions.")
    source_hash = canonical_hash(
        [
            [file.relative_path, file.content_hash, file.size_bytes]
            for file in manifest.source_inventory
        ]
    )
    if manifest.input_hashes.get("source_contents") != source_hash:
        raise DatasetPreparationError("Source inventory integrity hash mismatch.")


def enumerate_classes() -> tuple[tuple[str, int], ...]:
    return tuple((label, index) for index, label in enumerate(CLASS_LABELS))


def load_manifest(path: Path) -> DatasetManifest:
    manifest = DatasetManifest.model_validate_json(path.read_bytes())
    _validate_manifest(manifest)
    return manifest


def verify_manifest(manifest: DatasetManifest, dataset_root: Path | None = None) -> None:
    """Verify content/partition integrity immediately before training or evaluation."""
    _validate_manifest(manifest)
    root = load_dataset_path() if dataset_root is None else dataset_root.resolve(strict=True)
    _verify_source_files(root, manifest.source_inventory)


def grouped_stratified_split(rows: tuple[SampleRecord, ...]) -> SplitDefinition:
    grouped: dict[str, list[SampleRecord]] = defaultdict(list)
    for row in rows:
        grouped[row.group_id].append(row)
    if any(len({row.label for row in group}) != 1 for group in grouped.values()):
        raise DatasetPreparationError("Conflicting labels remain in an eligible content group.")
    partitions: dict[SplitName, list[str]] = {name: [] for name in SPLIT_NAMES}
    for label in CLASS_LABELS:
        groups = [group for group in grouped.values() if group[0].label == label]
        if len(groups) < 3:
            raise DatasetPreparationError(
                "Each class needs three independent groups for splitting."
            )
        groups.sort(key=lambda g: canonical_hash([SEED, label, g[0].group_id]))
        total = sum(len(group) for group in groups)
        targets = {"train": total * 0.7, "validation": total * 0.15, "test": total * 0.15}
        counts = {name: 0 for name in SPLIT_NAMES}
        for group in groups:
            split = min(SPLIT_NAMES, key=lambda name: counts[name] / targets[name])
            partitions[split].extend(row.sample_id for row in group)
            counts[split] += len(group)
    return SplitDefinition(**{name: tuple(sorted(ids)) for name, ids in partitions.items()})


def _public_provenance(links: tuple[_LinkedFile, ...]) -> SourceProvenance:
    references: dict[str, SourceReference] = {}
    for link in links:
        for source in link.matching_source_members:
            reference = SourceReference(
                dataset_version_id=source.source_dataset_version_id,
                variant=source.variant,
                source_class=source.source_class,
                original_name=source.original_name,
                declared_origin=source.archive_name == link.archive_origin,
            )
            references[reference.model_dump_json()] = reference
    return SourceProvenance(
        references=tuple(references[key] for key in sorted(references)),
        original_ids=tuple(sorted({key for link in links for key in link.recovered_original_ids})),
        original_uuids=tuple(
            sorted({key for link in links for key in link.recovered_original_uuids})
        ),
    )


def prepare_dataset(
    destination: Path,
    *,
    version: str = "maize-research-20261007-v1",
    inventory_path: Path = _REVIEW / "inventory.json",
    source_linkage_path: Path = _REPOSITORY / ".cache/phase95-source-linkage.json",
    source_index_path: Path = _REPOSITORY / ".cache/phase95-source-index.json",
    evidence_path: Path = _PROJECT / "configs/group-evidence.json",
    policy_path: Path = _PROJECT / "configs/research-policy.json",
    preprocessing_path: Path = _PROJECT / "configs/full-frame-baseline.json",
) -> DatasetManifest:
    """Freeze only manifests and safe provenance; all raw files stay in their original directory."""
    if not version or any(
        character not in "abcdefghijklmnopqrstuvwxyz0123456789-_." for character in version
    ):
        raise DatasetPreparationError("Dataset version must be a safe lowercase identifier.")
    root = load_dataset_path()
    destination = validate_destination(root, destination)
    evidence = _Evidence.model_validate_json(evidence_path.read_bytes())
    input_paths = {
        "inventory": inventory_path,
        "source_linkage": source_linkage_path,
        "source_index": source_index_path,
        "manual_review": _REPOSITORY / ".cache/phase95-manual-review.json",
        "near_candidates": _REVIEW / "near-duplicate-candidates.json",
    }
    for name, source_input_path in input_paths.items():
        if name not in evidence.input_hashes and name in {"manual_review", "near_candidates"}:
            continue
        if evidence.input_hashes.get(name) != file_digest(source_input_path):
            raise DatasetPreparationError("Dataset review evidence input hash mismatch.")
    records = TypeAdapter(tuple[_InventoryRecord, ...]).validate_json(inventory_path.read_bytes())
    if not records or {record.label for record in records} != set(CLASS_LABELS):
        raise DatasetPreparationError("Inventory must contain exactly the four literal classes.")
    if any(record.split is not None for record in records):
        raise DatasetPreparationError(
            "Existing split directories must not be reshuffled automatically."
        )
    if any(PurePosixPath(record.relative_path).parts[0] != record.label for record in records):
        raise DatasetPreparationError("Inventory labels differ from literal source directories.")
    by_path = {record.relative_path: record for record in records}
    if len(by_path) != len(records):
        raise DatasetPreparationError("Inventory paths must be unique.")
    original_files = tuple(
        SourceFile(
            relative_path=record.relative_path,
            content_hash=record.sha256,
            size_bytes=record.size_bytes,
            disposition="excluded",
            sample_id=None,
        )
        for record in records
    )
    _verify_source_files(root, original_files)
    linkage = _Linkage.model_validate_json(source_linkage_path.read_bytes())
    source_index = _SourceIndex.model_validate_json(source_index_path.read_bytes())
    links = {file.relative_path: file for file in linkage.files}
    if not linkage.inventory_complete or set(links) != set(by_path):
        raise DatasetPreparationError("Source linkage must cover the pinned inventory.")
    for relative_path, link in links.items():
        if (
            link.sha256 != by_path[relative_path].sha256
            or link.label != by_path[relative_path].label
        ):
            raise DatasetPreparationError("Source linkage differs from inventory identity.")
        source_members = source_index.by_sha256.get(link.sha256, ())
        if not link.matching_source_members or any(
            member not in source_members for member in link.matching_source_members
        ):
            raise DatasetPreparationError("Source linkage is not corroborated by the source index.")
    config = PreprocessingConfig.model_validate_json(preprocessing_path.read_bytes())
    if config.segmentation.mode != "disabled":
        raise DatasetPreparationError("The approved baseline requires full-frame preprocessing.")
    policy = _read_object(policy_path)
    hashes = {record.sha256 for record in records}
    related = _Groups(hashes)
    equivalent = _Groups(hashes)
    # Pixel equivalence is safe only for single-frame RGB without an ICC conversion.
    pixel_first: dict[str, str] = {}
    for record in records:
        if (
            record.mode == "RGB"
            and record.frames == 1
            and "icc_profile" not in record.metadata_keys
            and record.pixel_hash
            and "disabled_error" not in record.preprocessing
        ):
            first = pixel_first.setdefault(record.pixel_hash, record.sha256)
            equivalent.join(first, record.sha256)
            related.join(first, record.sha256)
    first_identity: dict[str, str] = {}
    for link in links.values():
        keys = [f"original:{key}" for key in link.recovered_original_ids]
        keys += [f"uuid:{key}" for key in link.recovered_original_uuids]
        for key in keys:
            related.join(first_identity.setdefault(key, link.sha256), link.sha256)
    for edge in evidence.confirmed_edges:
        if edge.first_hash not in hashes or edge.second_hash not in hashes:
            raise DatasetPreparationError("Confirmed relationship references absent content.")
        related.join(edge.first_hash, edge.second_hash)
    invalid = {item.content_hash: item.reason_code for item in evidence.invalid_inputs}
    observed_invalid: dict[str, str] = {}
    for record in records:
        error = record.preprocessing.get("disabled_error")
        if isinstance(error, str):
            observed_invalid[record.sha256] = f"INVALID_INPUT:{error}"
        elif "disabled" not in record.preprocessing:
            raise DatasetPreparationError(
                "Every source requires a successful shared-policy check or exclusion."
            )
    if observed_invalid != invalid:
        raise DatasetPreparationError(
            "Approved invalid-input exclusions differ from review results."
        )
    conflict_roots: dict[str, str] = {}
    for family in evidence.conflicting_families:
        if not family.content_hashes or any(value not in hashes for value in family.content_hashes):
            raise DatasetPreparationError("Contradictory family references absent content.")
        roots = {related.find(value) for value in family.content_hashes}
        if len(roots) != 1:
            raise DatasetPreparationError(
                "Contradictory-family closure lacks verified relationships."
            )
        conflict_roots[roots.pop()] = family.family_id
    excluded: list[ExclusionRecord] = []
    valid: list[_InventoryRecord] = []
    for record in records:
        codes: list[str] = []
        if record.sha256 in invalid:
            codes.append(invalid[record.sha256])
        family_id = conflict_roots.get(related.find(record.sha256))
        if family_id is not None:
            codes.append("CONTRADICTORY_LABEL_FAMILY")
        if codes:
            excluded.append(
                ExclusionRecord(
                    relative_path=record.relative_path,
                    content_hash=record.sha256,
                    label=record.label,
                    reason_codes=tuple(codes),
                    family_id=family_id,
                )
            )
        else:
            valid.append(record)
    components: dict[str, set[str]] = defaultdict(set)
    for content_hash in hashes:
        components[related.find(content_hash)].add(content_hash)
    content_groups: dict[str, list[_InventoryRecord]] = defaultdict(list)
    for record in valid:
        content_groups[equivalent.find(record.sha256)].append(record)
    eligible: list[SampleRecord] = []
    class_map = dict(enumerate_classes())
    for group in content_groups.values():
        group.sort(key=lambda record: record.relative_path)
        canonical = group[0]
        if len({record.label for record in group}) != 1:
            raise DatasetPreparationError("Unresolved contradictory labels in duplicate content.")
        group_contents = components[related.find(canonical.sha256)]
        eligible.append(
            SampleRecord(
                sample_id=canonical.sha256,
                content_hash=canonical.sha256,
                pixel_hash=canonical.pixel_hash,
                label=canonical.label,
                class_index=class_map[canonical.label],
                relative_path=canonical.relative_path,
                group_id=canonical_hash(sorted(group_contents)),
                duplicate_paths=tuple(record.relative_path for record in group[1:]),
                provenance=_public_provenance(
                    tuple(links[record.relative_path] for record in group)
                ),
            )
        )
    rows = tuple(sorted(eligible, key=lambda row: row.sample_id))
    splits = grouped_stratified_split(rows)
    disposition: dict[str, tuple[str, str]] = {}
    for row in rows:
        disposition[row.relative_path] = ("eligible", row.sample_id)
        for alias_path in row.duplicate_paths:
            disposition[alias_path] = ("duplicate", row.sample_id)
    source_files = tuple(
        file.model_copy(
            update={
                "disposition": disposition[file.relative_path][0],
                "sample_id": disposition[file.relative_path][1],
            }
        )
        if file.relative_path in disposition
        else file
        for file in original_files
    )
    input_hashes = {
        **evidence.input_hashes,
        "group_evidence": file_digest(evidence_path),
        "research_policy": file_digest(policy_path),
        "preprocessing_file": file_digest(preprocessing_path),
        "source_contents": canonical_hash(
            [[file.relative_path, file.content_hash, file.size_bytes] for file in source_files]
        ),
    }
    config_json = _read_object(preprocessing_path)
    counts: dict[str, int] = {
        "source_files": len(records),
        "source_unique_byte_contents": len(hashes),
        "excluded_files": len(excluded),
        "excluded_unique_contents": len({row.content_hash for row in excluded}),
        "eligible_unique_samples": len(rows),
        "duplicate_aliases": sum(len(row.duplicate_paths) for row in rows),
        "eligible_groups": len({row.group_id for row in rows}),
        **{name: len(ids) for name, ids in splits.as_mapping().items()},
    }
    manifest = DatasetManifest(
        version=version,
        fingerprint="0" * 64,
        classes=tuple(
            ClassDefinition(label=label, index=index) for label, index in enumerate_classes()
        ),
        eligible=rows,
        excluded=tuple(sorted(excluded, key=lambda row: row.relative_path)),
        source_inventory=source_files,
        splits=splits,
        split_seed=SEED,
        split_ratios=(0.7, 0.15, 0.15),
        preprocessing_config=config_json,
        preprocessing_hash=config.fingerprint,
        input_hashes=input_hashes,
        research_policy=policy,
        counts=counts,
    )
    manifest = manifest.model_copy(
        update={
            "fingerprint": canonical_hash(manifest.model_dump(mode="json", exclude={"fingerprint"}))
        }
    )
    verify_manifest(manifest, root)
    destination.mkdir(parents=True)
    payloads: dict[str, object] = {
        "manifest.json": manifest.model_dump(mode="json"),
        "eligibility.json": [row.model_dump(mode="json") for row in rows],
        "exclusions.json": [row.model_dump(mode="json") for row in manifest.excluded],
        "class-map.json": [entry.model_dump(mode="json") for entry in manifest.classes],
        "splits.json": splits.model_dump(mode="json"),
        "provenance.json": {
            "input_hashes": input_hashes,
            "research_policy": policy,
            "source_contents_hash": input_hashes["source_contents"],
        },
        "preprocessing.json": config_json,
        "research-policy.json": policy,
    }
    for filename, value in payloads.items():
        with (destination / filename).open("x", encoding="utf-8") as stream:
            stream.write(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n")
    integrity = {name: file_digest(destination / name) for name in sorted(payloads)}
    with (destination / "integrity.json").open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(integrity, indent=2, sort_keys=True) + "\n")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create a versioned research index without changing source images"
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", default="maize-research-20261007-v1")
    args = parser.parse_args()
    manifest = prepare_dataset(args.output, version=args.version)
    print(
        json.dumps(
            {
                "version": manifest.version,
                "fingerprint": manifest.fingerprint,
                "counts": manifest.counts,
                "class_counts": dict(Counter(row.label for row in manifest.eligible)),
                "split_classes": {
                    name: dict(Counter(row.label for row in manifest.rows_for_split(name)))
                    for name in SPLIT_NAMES
                },
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
