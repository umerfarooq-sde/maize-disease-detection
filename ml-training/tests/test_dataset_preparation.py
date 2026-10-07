"""Recorded exclusions, derivative grouping and immutable source/index boundaries."""

import json
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import cast

import pytest
from maizedoctor_preprocessing import PreprocessingConfig, PreprocessingError, SegmentationConfig
from PIL import Image

from dataset_inventory import file_digest, inspect_image
from dataset_preparation import (
    CLASS_LABELS,
    DatasetPreparationError,
    canonical_hash,
    load_manifest,
    prepare_dataset,
    verify_manifest,
)
from preprocessing import preprocess_file


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


@dataclass
class PreparedFixture:
    root: Path
    inventory_path: Path
    source_linkage_path: Path
    source_index_path: Path
    evidence_path: Path
    policy_path: Path
    preprocessing_path: Path

    def prepare(self, output: Path):
        return prepare_dataset(
            output,
            inventory_path=self.inventory_path,
            source_linkage_path=self.source_linkage_path,
            source_index_path=self.source_index_path,
            evidence_path=self.evidence_path,
            policy_path=self.policy_path,
            preprocessing_path=self.preprocessing_path,
        )

    def repin(self, name: str, path: Path) -> None:
        evidence = json.loads(self.evidence_path.read_text(encoding="utf-8"))
        evidence["input_hashes"][name] = file_digest(path)
        write_json(self.evidence_path, evidence)


@pytest.fixture
def source_fixture(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> PreparedFixture:
    root = tmp_path / "raw originals"
    for class_index, label in enumerate(CLASS_LABELS):
        directory = root / label
        directory.mkdir(parents=True)
        for number in range(12):
            color = (20 + class_index * 40, 25 + number * 13, 240 - number * 11)
            Image.new("RGB", (48, 40), color).save(directory / f"image-{number}.png")
    rust = root / "Common_Rust"
    gray = root / "Gray_Leaf_Spot"
    healthy = root / "Healthy"
    blight = root / "Northern_Corn_Leaf_Blight"
    (rust / "byte-copy.png").write_bytes((rust / "image-1.png").read_bytes())
    with Image.open(rust / "image-1.png") as image:
        image.save(rust / "pixel-copy.png", compress_level=0)
    (gray / "conflict-copy.png").write_bytes((rust / "image-0.png").read_bytes())
    with Image.open(rust / "image-0.png") as image:
        image.transpose(Image.Transpose.ROTATE_90).save(blight / "conflict-rotated.png")
    (rust / "invalid.png").write_bytes(b"broken source file")
    Image.new("RGBA", (48, 40), (43, 52, 63, 255)).save(healthy / "alpha-opaque.png")
    Image.new("RGBA", (48, 40), (43, 52, 63, 128)).save(healthy / "alpha-translucent.png")

    metadata = tmp_path / "private review metadata"
    metadata.mkdir()
    config = PreprocessingConfig(segmentation=SegmentationConfig(mode="disabled"))
    records = []
    for path in sorted(root.rglob("*.png")):
        record = asdict(inspect_image(root, path))
        try:
            preprocess_file(path, config)
            record["preprocessing"] = {"disabled": {"validated": True}}
        except PreprocessingError as error:
            record["preprocessing"] = {"disabled_error": error.code.value}
        records.append(record)
    by_path = {record["relative_path"]: record for record in records}
    members_by_hash = defaultdict(list)
    linked = []
    for record in records:
        relative = cast(str, record["relative_path"])
        member = {
            "source_dataset_version_id": "fixture/1",
            "archive_name": "source.zip",
            "variant": "color",
            "original_name": Path(relative).name,
            "original_uuid": "",
            "source_class": record["label"],
        }
        original_ids = [f"fixture:{relative}"]
        if relative in {"Common_Rust/image-2.png", "Common_Rust/image-3.png"}:
            original_ids = ["fixture:confirmed-original-family"]
        members_by_hash[record["sha256"]].append(member)
        linked.append(
            {
                "relative_path": relative,
                "label": record["label"],
                "sha256": record["sha256"],
                "archive_origin": "source.zip",
                "matching_source_members": [member],
                "recovered_original_uuids": [],
                "recovered_original_ids": original_ids,
            }
        )
    fixture = PreparedFixture(
        root,
        metadata / "inventory.json",
        metadata / "linkage.json",
        metadata / "source-index.json",
        metadata / "evidence.json",
        metadata / "policy.json",
        metadata / "preprocessing.json",
    )
    write_json(fixture.inventory_path, records)
    write_json(fixture.source_linkage_path, {"inventory_complete": True, "files": linked})
    write_json(
        fixture.source_index_path,
        {"archives": {str(metadata / "private source.zip"): {}}, "by_sha256": members_by_hash},
    )
    write_json(
        fixture.evidence_path,
        {
            "schema_version": 1,
            "input_hashes": {
                "inventory": file_digest(fixture.inventory_path),
                "source_linkage": file_digest(fixture.source_linkage_path),
                "source_index": file_digest(fixture.source_index_path),
            },
            "invalid_inputs": [
                {
                    "content_hash": record["sha256"],
                    "reason_code": "INVALID_INPUT:" + record["preprocessing"]["disabled_error"],
                }
                for record in records
                if "disabled_error" in record["preprocessing"]
            ],
            "conflicting_families": [
                {
                    "family_id": "known-cross-label-original-and-rotation",
                    "content_hashes": [
                        by_path["Common_Rust/image-0.png"]["sha256"],
                        by_path["Northern_Corn_Leaf_Blight/conflict-rotated.png"]["sha256"],
                    ],
                    "reason_code": "CONTRADICTORY_LABEL_FAMILY",
                }
            ],
            "confirmed_edges": [
                {
                    "first_hash": by_path["Common_Rust/image-0.png"]["sha256"],
                    "second_hash": by_path["Northern_Corn_Leaf_Blight/conflict-rotated.png"][
                        "sha256"
                    ],
                    "kind": "VISUALLY_CONFIRMED_ROTATION",
                },
                {
                    "first_hash": by_path["Common_Rust/image-4.png"]["sha256"],
                    "second_hash": by_path["Common_Rust/image-5.png"]["sha256"],
                    "kind": "VISUALLY_CONFIRMED_NEAR",
                },
            ],
        },
    )
    write_json(
        fixture.policy_path,
        {
            "permitted_use": "non-commercial academic/FYP research only",
            "raw_image_redistribution": False,
            "commercial_clearance": False,
        },
    )
    fixture.preprocessing_path.write_text(config.model_dump_json(indent=2), encoding="utf-8")
    monkeypatch.setenv("DATASET_PATH", str(root))
    return fixture


def test_manifest_exclusions_duplicates_grouped_splits_and_source_privacy(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    before = {
        path: (file_digest(path), path.stat().st_mtime_ns)
        for path in source_fixture.root.rglob("*.png")
    }
    manifest = source_fixture.prepare(tmp_path / "version-one")
    assert manifest.counts["source_files"] == 55
    assert manifest.counts["excluded_files"] == 4
    assert manifest.counts["excluded_unique_contents"] == 3
    assert manifest.counts["eligible_unique_samples"] == 49
    assert manifest.counts["duplicate_aliases"] == 2
    assert manifest.counts["eligible_groups"] == 47
    assert [(item.label, item.index) for item in manifest.classes] == list(
        zip(CLASS_LABELS, range(4), strict=True)
    )
    assert (
        Counter(code for row in manifest.excluded for code in row.reason_codes)[
            "CONTRADICTORY_LABEL_FAMILY"
        ]
        == 3
    )
    assert any(
        code.startswith("INVALID_INPUT:") for row in manifest.excluded for code in row.reason_codes
    )
    group_splits = defaultdict(set)
    for split, ids in manifest.splits.as_mapping().items():
        assert ids
        assert {row.label for row in manifest.rows_for_split(split)} == set(CLASS_LABELS)
        for row in manifest.rows_for_split(split):
            group_splits[row.group_id].add(split)
    assert all(len(splits) == 1 for splits in group_splits.values())
    rows_by_path = {row.relative_path: row for row in manifest.eligible}
    assert (
        rows_by_path["Common_Rust/image-2.png"].group_id
        == rows_by_path["Common_Rust/image-3.png"].group_id
    )
    assert (
        rows_by_path["Common_Rust/image-4.png"].group_id
        == rows_by_path["Common_Rust/image-5.png"].group_id
    )
    assert (
        rows_by_path["Healthy/alpha-opaque.png"].pixel_hash
        == rows_by_path["Healthy/alpha-translucent.png"].pixel_hash
    )
    assert (
        rows_by_path["Healthy/alpha-opaque.png"].sample_id
        != rows_by_path["Healthy/alpha-translucent.png"].sample_id
    )
    loaded = load_manifest(tmp_path / "version-one/manifest.json")
    assert loaded == manifest
    verify_manifest(loaded)
    assert before == {
        path: (file_digest(path), path.stat().st_mtime_ns)
        for path in source_fixture.root.rglob("*.png")
    }
    for file in (tmp_path / "version-one").iterdir():
        assert file.suffix == ".json"
        assert str(tmp_path) not in file.read_text(encoding="utf-8")


def test_manifest_and_splits_are_reproducible(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    first = source_fixture.prepare(tmp_path / "first")
    second = source_fixture.prepare(tmp_path / "second")
    assert first.fingerprint == second.fingerprint
    assert first.splits == second.splits
    assert (tmp_path / "first/manifest.json").read_bytes() == (
        tmp_path / "second/manifest.json"
    ).read_bytes()


def test_raw_mutation_and_addition_are_detected(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    manifest = source_fixture.prepare(tmp_path / "version-one")
    original = source_fixture.root / "Common_Rust/image-8.png"
    original.write_bytes(original.read_bytes() + b"changed")
    with pytest.raises(DatasetPreparationError, match="contents differ"):
        verify_manifest(manifest)
    with pytest.raises(DatasetPreparationError, match="contents differ"):
        source_fixture.prepare(tmp_path / "version-two")
    assert not (tmp_path / "version-two").exists()


def test_extra_source_member_is_detected(source_fixture: PreparedFixture, tmp_path: Path) -> None:
    manifest = source_fixture.prepare(tmp_path / "version-one")
    (source_fixture.root / "added.txt").write_text("new data", encoding="utf-8")
    with pytest.raises(DatasetPreparationError, match="file membership differs"):
        verify_manifest(manifest)


def test_output_inside_source_or_existing_directory_is_rejected(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    with pytest.raises(ValueError, match="outside"):
        source_fixture.prepare(source_fixture.root / "generated")
    with pytest.raises(ValueError, match="overwrite"):
        source_fixture.prepare(tmp_path)
    assert not (source_fixture.root / "generated").exists()


def test_input_evidence_hash_mismatch_is_rejected(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    source_fixture.inventory_path.write_text(
        source_fixture.inventory_path.read_text(encoding="utf-8") + "\n", encoding="utf-8"
    )
    with pytest.raises(DatasetPreparationError, match="input hash mismatch"):
        source_fixture.prepare(tmp_path / "output")
    assert not (tmp_path / "output").exists()


def test_existing_splits_are_not_silently_reshuffled(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    records = json.loads(source_fixture.inventory_path.read_text(encoding="utf-8"))
    records[0]["split"] = "train"
    write_json(source_fixture.inventory_path, records)
    source_fixture.repin("inventory", source_fixture.inventory_path)
    with pytest.raises(DatasetPreparationError, match="must not be reshuffled"):
        source_fixture.prepare(tmp_path / "output")


def test_source_linkage_must_cover_and_corroborate_inventory(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    source_index = json.loads(source_fixture.source_index_path.read_text(encoding="utf-8"))
    source_index["by_sha256"] = {}
    write_json(source_fixture.source_index_path, source_index)
    source_fixture.repin("source_index", source_fixture.source_index_path)
    with pytest.raises(DatasetPreparationError, match="not corroborated"):
        source_fixture.prepare(tmp_path / "output")


def test_manifest_tamper_and_recalculated_split_leakage_are_rejected(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    manifest = source_fixture.prepare(tmp_path / "version-one")
    path = tmp_path / "changed-manifest.json"
    value = manifest.model_dump(mode="json")
    value["counts"]["eligible_unique_samples"] += 1
    write_json(path, value)
    with pytest.raises(DatasetPreparationError, match="fingerprint mismatch"):
        load_manifest(path)
    value = manifest.model_dump(mode="json")
    grouped = defaultdict(list)
    for row in manifest.eligible:
        grouped[row.group_id].append(row.sample_id)
    pair = next(group for group in grouped.values() if len(group) == 2)
    old_split = next(name for name, ids in value["splits"].items() if pair[0] in ids)
    new_split = "validation" if old_split != "validation" else "test"
    value["splits"][old_split].remove(pair[0])
    value["splits"][new_split].append(pair[0])
    value["fingerprint"] = canonical_hash(
        {key: field for key, field in value.items() if key != "fingerprint"}
    )
    write_json(path, value)
    with pytest.raises(DatasetPreparationError, match="groups cross split"):
        load_manifest(path)


def test_unapproved_invalid_exclusion_is_rejected(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    evidence = json.loads(source_fixture.evidence_path.read_text(encoding="utf-8"))
    evidence["invalid_inputs"] = []
    write_json(source_fixture.evidence_path, evidence)
    with pytest.raises(DatasetPreparationError, match="invalid-input exclusions differ"):
        source_fixture.prepare(tmp_path / "output")


def test_inventory_traversal_is_rejected_before_source_access(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    records = json.loads(source_fixture.inventory_path.read_text(encoding="utf-8"))
    records[0]["relative_path"] = "../private.txt"
    write_json(source_fixture.inventory_path, records)
    source_fixture.repin("inventory", source_fixture.inventory_path)
    with pytest.raises(ValueError, match="safe relative paths"):
        source_fixture.prepare(tmp_path / "output")
    assert not (tmp_path / "output").exists()


def test_rehashed_manifest_cannot_relabel_literal_source_classes(
    source_fixture: PreparedFixture, tmp_path: Path
) -> None:
    manifest = source_fixture.prepare(tmp_path / "version-one")
    value = manifest.model_dump(mode="json")
    row = value["eligible"][0]
    different_class = next(entry for entry in value["classes"] if entry["label"] != row["label"])
    row["label"], row["class_index"] = different_class["label"], different_class["index"]
    value["fingerprint"] = canonical_hash(
        {key: field for key, field in value.items() if key != "fingerprint"}
    )
    write_json(tmp_path / "relabeled.json", value)
    with pytest.raises(DatasetPreparationError, match="literal source directory"):
        load_manifest(tmp_path / "relabeled.json")
