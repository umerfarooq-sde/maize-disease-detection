"""Versioned correction of confirmed parent relationships, preserving raw data and v1.

Labels, raw files, previous exclusions, seed, split algorithm and preprocessing are
unchanged. Newly confirmed contradictory parent families become reason-coded index
exclusions. A fresh model must be trained; a model fitted on v1 cannot reuse v2 as an
independent holdout. Uncertain perceptual candidates are never accepted as evidence.
"""

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, JsonValue

from configuration import load_dataset_path
from dataset_inventory import file_digest
from dataset_preparation import (
    DatasetManifest,
    Digest,
    ExclusionRecord,
    SampleRecord,
    canonical_hash,
    grouped_stratified_split,
    load_manifest,
    verify_manifest,
)
from dataset_review import validate_destination
from fitness_integrity import relationship_audit


class ConfirmedRelation(BaseModel):
    model_config = ConfigDict(frozen=True, extra="ignore", strict=True)
    first_hash: Digest
    second_hash: Digest
    kind: Literal[
        "VISUALLY_CONFIRMED_SHARED_LEAF_REGION",
        "VISUALLY_CONFIRMED_TRANSFORMED_PHOTO",
    ]
    reason: str = Field(min_length=20)


class RepairEvidence(BaseModel):
    model_config = ConfigDict(frozen=True, extra="ignore", strict=True)
    schema_version: Literal[1]
    review_status: Literal["FINAL_CONFIRMED_RELATIONS"]
    parent_manifest_fingerprint: Digest
    confirmed_edges: tuple[ConfirmedRelation, ...] = Field(min_length=1)


def repair_groups(
    original: DatasetManifest, evidence: RepairEvidence, *, version: str
) -> DatasetManifest:
    """Pure index transition; callers verify source before/after persistence."""
    if (
        not version
        or version == original.version
        or evidence.parent_manifest_fingerprint != original.fingerprint
    ):
        raise ValueError("Repair requires a new version and evidence for this exact parent index.")
    rows_by_hash = {row.content_hash: row for row in original.eligible}
    parents = {content: content for content in rows_by_hash}

    def find(content: str) -> str:
        cursor = content
        while parents[cursor] != cursor:
            cursor = parents[cursor]
        while parents[content] != content:
            following = parents[content]
            parents[content] = cursor
            content = following
        return cursor

    def union(first: str, second: str) -> None:
        first, second = find(first), find(second)
        if first != second:
            smaller, larger = sorted((first, second))
            parents[larger] = smaller

    previous_groups: dict[str, list[str]] = defaultdict(list)
    for row in original.eligible:
        previous_groups[row.group_id].append(row.content_hash)
    for members in previous_groups.values():
        for member in members[1:]:
            union(members[0], member)
    for edge in evidence.confirmed_edges:
        first, second = rows_by_hash.get(edge.first_hash), rows_by_hash.get(edge.second_hash)
        if first is None or second is None or first.content_hash == second.content_hash:
            raise ValueError("Confirmed relations must reference two distinct eligible contents.")
        union(first.content_hash, second.content_hash)
    groups: dict[str, list[str]] = defaultdict(list)
    for content in rows_by_hash:
        groups[find(content)].append(content)
    group_ids = {root: canonical_hash(sorted(members)) for root, members in groups.items()}
    conflicts = {
        group_root: members
        for group_root, members in groups.items()
        if len({rows_by_hash[content].label for content in members}) > 1
    }
    excluded_contents = {content for members in conflicts.values() for content in members}
    excluded_paths = {
        path: rows_by_hash[content]
        for content in excluded_contents
        for path in (
            rows_by_hash[content].relative_path,
            *rows_by_hash[content].duplicate_paths,
        )
    }
    source_by_path = {entry.relative_path: entry for entry in original.source_inventory}
    new_exclusions = tuple(
        ExclusionRecord(
            relative_path=path,
            content_hash=source_by_path[path].content_hash,
            label=row.label,
            reason_codes=(
                "CONTRADICTORY_LABEL_FAMILY",
                "PHASE105_NEW_CONTRADICTORY_FAMILY",
            ),
            family_id=f"phase105-conflict-{group_ids[find(row.content_hash)]}",
        )
        for path, row in sorted(excluded_paths.items())
    )
    exclusions = (*original.excluded, *new_exclusions)
    source_inventory = tuple(
        entry.model_copy(update={"disposition": "excluded", "sample_id": None})
        if entry.relative_path in excluded_paths
        else entry
        for entry in original.source_inventory
    )
    rows: tuple[SampleRecord, ...] = tuple(
        row.model_copy(update={"group_id": group_ids[find(row.content_hash)]})
        for row in original.eligible
        if row.content_hash not in excluded_contents
    )
    splits = grouped_stratified_split(rows)
    counts: dict[str, int] = {
        **original.counts,
        "eligible_unique_samples": len(rows),
        "eligible_groups": len(groups) - len(conflicts),
        "duplicate_aliases": sum(len(row.duplicate_paths) for row in rows),
        "excluded_files": len(exclusions),
        "excluded_unique_contents": len({entry.content_hash for entry in exclusions}),
        **{name: len(sample_ids) for name, sample_ids in splits.as_mapping().items()},
    }
    changed = original.model_copy(
        update={
            "version": version,
            "eligible": rows,
            "excluded": exclusions,
            "source_inventory": source_inventory,
            "splits": splits,
            "counts": counts,
        }
    )
    return changed.model_copy(
        update={
            "fingerprint": canonical_hash(changed.model_dump(mode="json", exclude={"fingerprint"}))
        }
    )


def repair_dataset(
    parent_manifest_path: Path,
    evidence_path: Path,
    output: Path,
    *,
    version: str = "maize-research-20261008-v2",
) -> DatasetManifest:
    """Verify all configured raw bytes, save a new index exclusively, and reverify."""
    root = load_dataset_path()
    destination = validate_destination(root, output)
    parent_bytes = parent_manifest_path.read_bytes()
    evidence_bytes = evidence_path.read_bytes()
    original = load_manifest(parent_manifest_path)
    evidence = RepairEvidence.model_validate_json(evidence_bytes)
    verify_manifest(original, root)
    repaired = repair_groups(original, evidence, version=version)
    repaired = repaired.model_copy(
        update={
            "input_hashes": {
                **original.input_hashes,
                "parent_manifest_file": file_digest(parent_manifest_path),
                "parent_manifest_fingerprint": original.fingerprint,
                "group_repair_evidence": file_digest(evidence_path),
            }
        }
    )
    repaired = repaired.model_copy(
        update={
            "fingerprint": canonical_hash(repaired.model_dump(mode="json", exclude={"fingerprint"}))
        }
    )
    verify_manifest(repaired, root)
    audit = relationship_audit(
        {name: repaired.rows_for_split(name) for name in repaired.splits.as_mapping()},
        confirmed_edges=((edge.first_hash, edge.second_hash) for edge in evidence.confirmed_edges),
        excluded_contents=(entry.content_hash for entry in repaired.excluded),
    )
    if audit["known_relationships_disjoint"] is not True:
        raise ValueError("The repaired index still contains a known relationship leak.")
    original_excluded_paths = {entry.relative_path for entry in original.excluded}
    added_exclusions = tuple(
        entry for entry in repaired.excluded if entry.relative_path not in original_excluded_paths
    )
    family_members: dict[str, list[JsonValue]] = defaultdict(list)
    for entry in added_exclusions:
        if entry.family_id is not None:
            family_members[entry.family_id].append(
                {
                    "relative_path": entry.relative_path,
                    "content_hash": entry.content_hash,
                    "label": entry.label,
                    "reason_codes": list(entry.reason_codes),
                }
            )
    old_split = {
        sample: name for name, ids in original.splits.as_mapping().items() for sample in ids
    }
    new_split: dict[str, str] = {
        sample: name for name, ids in repaired.splits.as_mapping().items() for sample in ids
    }
    for sample in old_split.keys() - new_split.keys():
        new_split[sample] = "excluded"
    transitions: dict[str, JsonValue] = {
        f"{first}/{second}": sum(
            old_split[sample] == first and new_split[sample] == second for sample in old_split
        )
        for first in original.splits.as_mapping()
        for second in (*repaired.splits.as_mapping(), "excluded")
    }
    report: dict[str, JsonValue] = {
        "parent_version": original.version,
        "parent_manifest_fingerprint": original.fingerprint,
        "version": repaired.version,
        "manifest_fingerprint": repaired.fingerprint,
        "confirmed_edges": len(evidence.confirmed_edges),
        "original_groups": original.counts["eligible_groups"],
        "repaired_groups": repaired.counts["eligible_groups"],
        "moved_samples": sum(
            old_split[sample] != new_split[sample]
            for sample in old_split
            if new_split[sample] != "excluded"
        ),
        "partition_transitions": transitions,
        "new_contradictory_family_count": len(family_members),
        "new_excluded_files": len(added_exclusions),
        "new_excluded_unique_contents": len({entry.content_hash for entry in added_exclusions}),
        "new_excluded_files_by_class": dict(Counter(entry.label for entry in added_exclusions)),
        "new_excluded_unique_by_class": {
            label: len({entry.content_hash for entry in added_exclusions if entry.label == label})
            for label in {entry.label for entry in added_exclusions}
        },
        "new_contradictory_family_members": {
            family: members for family, members in family_members.items()
        },
        "changed_eligibility": bool(added_exclusions),
        "changed_exclusions": bool(added_exclusions),
        "changed_labels": False,
        "changed_raw_bytes": False,
        "changed_policy_seed_preprocessing": False,
        "raw_source_modified": False,
        "known_relationship_audit": audit,
        "scientific_boundary": (
            "v1 metrics are invalid for independent evaluation. Train a fresh model on v2; "
            "its repartitioned test is not a new external or never-inspected dataset."
        ),
    }
    destination.mkdir(parents=True, exist_ok=False)
    payloads: dict[str, object] = {
        "manifest.json": repaired.model_dump(mode="json"),
        "class-map.json": [entry.model_dump(mode="json") for entry in repaired.classes],
        "splits.json": repaired.splits.model_dump(mode="json"),
        "exclusions.json": [entry.model_dump(mode="json") for entry in repaired.excluded],
        "research-policy.json": repaired.research_policy,
        "preprocessing.json": repaired.preprocessing_config,
        "repair-evidence.json": evidence.model_dump(mode="json"),
        "repair-transition.json": report,
    }
    for name, value in payloads.items():
        with (destination / name).open("x", encoding="utf-8", newline="\n") as target:
            json.dump(value, target, indent=2, allow_nan=False)
            target.write("\n")
    integrity = {name: file_digest(destination / name) for name in payloads}
    with (destination / "integrity.json").open("x", encoding="utf-8", newline="\n") as target:
        json.dump(
            {"manifest_fingerprint": repaired.fingerprint, "files": integrity}, target, indent=2
        )
        target.write("\n")
    if (
        parent_manifest_path.read_bytes() != parent_bytes
        or evidence_path.read_bytes() != evidence_bytes
    ):
        raise ValueError("Parent index or confirmed evidence changed during repair.")
    restored = load_manifest(destination / "manifest.json")
    verify_manifest(restored, root)
    return restored


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--parent-manifest", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", default="maize-research-20261008-v2")
    args = parser.parse_args()
    manifest = repair_dataset(
        args.parent_manifest, args.evidence, args.output, version=args.version
    )
    print(
        json.dumps(
            {
                "version": manifest.version,
                "fingerprint": manifest.fingerprint,
                "counts": manifest.counts,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
