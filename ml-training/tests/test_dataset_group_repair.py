"""A leakage repair is a new reproducible index, never a source/label mutation."""

import json
from pathlib import Path

import pytest
from maizedoctor_preprocessing import PreprocessingConfig, SegmentationConfig
from PIL import Image
from pydantic import ValidationError

from dataset_group_repair import (
    ConfirmedRelation,
    RepairEvidence,
    repair_dataset,
    repair_groups,
)
from dataset_inventory import file_digest
from dataset_preparation import (
    CLASS_LABELS,
    ClassDefinition,
    DatasetManifest,
    ExclusionRecord,
    SampleRecord,
    SourceFile,
    SourceProvenance,
    canonical_hash,
    grouped_stratified_split,
    load_manifest,
    verify_manifest,
)


@pytest.fixture
def parent_index(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[Path, DatasetManifest]:
    root = tmp_path / "immutable raw samples"
    sources = []
    rows = []
    for index, label in enumerate(CLASS_LABELS):
        folder = root / label
        folder.mkdir(parents=True)
        for number in range(12):
            path = folder / f"original-{number}.png"
            Image.new("RGB", (48, 48), (30 + index * 50, 20 + number * 14, 150)).save(path)
            digest = file_digest(path)
            relative = path.relative_to(root).as_posix()
            sources.append(
                SourceFile(
                    relative_path=relative,
                    content_hash=digest,
                    size_bytes=path.stat().st_size,
                    disposition="eligible",
                    sample_id=digest,
                )
            )
            rows.append(
                SampleRecord(
                    sample_id=digest,
                    content_hash=digest,
                    pixel_hash=None,
                    label=label,
                    class_index=index,
                    relative_path=relative,
                    group_id=canonical_hash([digest]),
                    duplicate_paths=(),
                    provenance=SourceProvenance(references=(), original_ids=(), original_uuids=()),
                )
            )
    group = canonical_hash(sorted([rows[0].content_hash, rows[1].content_hash]))
    rows[0] = rows[0].model_copy(update={"group_id": group})
    rows[1] = rows[1].model_copy(update={"group_id": group})
    alias = root / CLASS_LABELS[0] / "same-bytes-alias.png"
    alias.write_bytes((root / rows[0].relative_path).read_bytes())
    alias_relative = alias.relative_to(root).as_posix()
    rows[0] = rows[0].model_copy(update={"duplicate_paths": (alias_relative,)})
    sources.append(
        SourceFile(
            relative_path=alias_relative,
            content_hash=rows[0].content_hash,
            size_bytes=alias.stat().st_size,
            disposition="duplicate",
            sample_id=rows[0].sample_id,
        )
    )
    invalid = root / CLASS_LABELS[0] / "invalid.png"
    invalid.write_bytes(b"known invalid input preserved")
    invalid_digest = file_digest(invalid)
    invalid_relative = invalid.relative_to(root).as_posix()
    sources.append(
        SourceFile(
            relative_path=invalid_relative,
            content_hash=invalid_digest,
            size_bytes=invalid.stat().st_size,
            disposition="excluded",
            sample_id=None,
        )
    )
    splits = grouped_stratified_split(tuple(rows))
    config = PreprocessingConfig(segmentation=SegmentationConfig(mode="disabled"))
    manifest = DatasetManifest(
        version="fixture-v1",
        fingerprint="0" * 64,
        classes=tuple(
            ClassDefinition(label=label, index=index) for index, label in enumerate(CLASS_LABELS)
        ),
        eligible=tuple(rows),
        excluded=(
            ExclusionRecord(
                relative_path=invalid_relative,
                content_hash=invalid_digest,
                label=CLASS_LABELS[0],
                reason_codes=("INVALID_INPUT:INVALID_IMAGE",),
                family_id=None,
            ),
        ),
        source_inventory=tuple(sources),
        splits=splits,
        split_seed=20261007,
        split_ratios=(0.7, 0.15, 0.15),
        preprocessing_config=json.loads(config.model_dump_json()),
        preprocessing_hash=config.fingerprint,
        input_hashes={
            "source_contents": canonical_hash(
                [[row.relative_path, row.content_hash, row.size_bytes] for row in sources]
            )
        },
        research_policy={"raw_image_redistribution": False, "commercial_clearance": False},
        counts={
            "source_files": 50,
            "source_unique_byte_contents": 49,
            "excluded_files": 1,
            "excluded_unique_contents": 1,
            "eligible_unique_samples": 48,
            "duplicate_aliases": 1,
            "eligible_groups": 47,
            **{name: len(ids) for name, ids in splits.as_mapping().items()},
        },
    )
    manifest = manifest.model_copy(
        update={
            "fingerprint": canonical_hash(manifest.model_dump(mode="json", exclude={"fingerprint"}))
        }
    )
    path = tmp_path / "parent.json"
    path.write_text(manifest.model_dump_json(indent=2), encoding="utf-8")
    monkeypatch.setenv("DATASET_PATH", str(root))
    verify_manifest(manifest)
    return path, manifest


def evidence_for(manifest: DatasetManifest) -> RepairEvidence:
    first = next(row for row in manifest.rows_for_split("train") if row.label == CLASS_LABELS[0])
    second = next(
        row for row in manifest.rows_for_split("validation") if row.label == CLASS_LABELS[0]
    )
    return RepairEvidence(
        schema_version=1,
        review_status="FINAL_CONFIRMED_RELATIONS",
        parent_manifest_fingerprint=manifest.fingerprint,
        confirmed_edges=(
            ConfirmedRelation(
                first_hash=first.content_hash,
                second_hash=second.content_hash,
                kind="VISUALLY_CONFIRMED_SHARED_LEAF_REGION",
                reason="Fixture parent identity is explicitly confirmed for testing.",
            ),
        ),
    )


def test_repair_preserves_sources_labels_exclusions_and_old_group_transitively(
    parent_index: tuple[Path, DatasetManifest],
) -> None:
    _, parent = parent_index
    evidence = evidence_for(parent)
    repaired = repair_groups(parent, evidence, version="fixture-v2")
    assert parent.version == "fixture-v1"
    assert repaired.version == "fixture-v2"
    assert repaired.counts["eligible_groups"] == 46
    assert repaired.source_inventory == parent.source_inventory
    assert repaired.excluded == parent.excluded
    assert repaired.classes == parent.classes
    assert repaired.research_policy == parent.research_policy
    assert repaired.preprocessing_hash == parent.preprocessing_hash
    assert repaired.split_seed == parent.split_seed
    for first, second in zip(parent.eligible, repaired.eligible, strict=True):
        assert first.model_dump(exclude={"group_id"}) == second.model_dump(exclude={"group_id"})
    by_hash = {row.content_hash: row for row in repaired.eligible}
    edge = evidence.confirmed_edges[0]
    assert by_hash[edge.first_hash].group_id == by_hash[edge.second_hash].group_id
    assert repaired.eligible[0].group_id == repaired.eligible[1].group_id
    assert repair_groups(parent, evidence, version="fixture-v2").fingerprint == repaired.fingerprint


def test_persistence_is_immutable_and_verifies_all_source_bytes(
    parent_index: tuple[Path, DatasetManifest], tmp_path: Path
) -> None:
    parent_path, parent = parent_index
    parent_before = parent_path.read_bytes()
    evidence_path = tmp_path / "confirmed.json"
    evidence_path.write_text(evidence_for(parent).model_dump_json(), encoding="utf-8")
    output = tmp_path / "v2 output"
    repaired = repair_dataset(parent_path, evidence_path, output, version="fixture-v2")
    assert load_manifest(output / "manifest.json") == repaired
    assert parent_path.read_bytes() == parent_before
    assert repaired.input_hashes["parent_manifest_file"] == file_digest(parent_path)
    assert repaired.input_hashes["group_repair_evidence"] == file_digest(evidence_path)
    verify_manifest(repaired)
    transition = json.loads((output / "repair-transition.json").read_bytes())
    assert transition["moved_samples"] > 0
    assert transition["known_relationship_audit"]["known_relationships_disjoint"]
    with pytest.raises(ValueError, match="new directory"):
        repair_dataset(parent_path, evidence_path, output, version="fixture-v2")


def test_changed_source_blocks_repair_before_output(
    parent_index: tuple[Path, DatasetManifest], tmp_path: Path
) -> None:
    parent_path, parent = parent_index
    evidence_path = tmp_path / "confirmed.json"
    evidence_path.write_text(evidence_for(parent).model_dump_json(), encoding="utf-8")
    root = tmp_path / "immutable raw samples"
    (root / parent.eligible[0].relative_path).write_bytes(b"unapproved change")
    output = tmp_path / "v2 output"
    with pytest.raises(ValueError, match="pinned inventory"):
        repair_dataset(parent_path, evidence_path, output, version="fixture-v2")
    assert not output.exists()


def test_repair_rejects_unknown_or_previously_excluded_content(
    parent_index: tuple[Path, DatasetManifest],
) -> None:
    _, parent = parent_index
    evidence = evidence_for(parent)
    for second_hash in ("f" * 64, parent.excluded[0].content_hash):
        edge = evidence.confirmed_edges[0].model_copy(update={"second_hash": second_hash})
        with pytest.raises(ValueError, match="eligible contents"):
            repair_groups(
                parent,
                evidence.model_copy(update={"confirmed_edges": (edge,)}),
                version="fixture-v2",
            )


def test_new_contradiction_excludes_whole_transitive_family_and_aliases(
    parent_index: tuple[Path, DatasetManifest], tmp_path: Path
) -> None:
    parent_path, parent = parent_index
    first, old_relative, further_parent = parent.eligible[:3]
    other = next(row for row in parent.eligible if row.label == CLASS_LABELS[1])
    reason = "Explicit visually confirmed fixture parent identity; no automatic relabeling."
    evidence = RepairEvidence(
        schema_version=1,
        review_status="FINAL_CONFIRMED_RELATIONS",
        parent_manifest_fingerprint=parent.fingerprint,
        confirmed_edges=(
            ConfirmedRelation(
                first_hash=first.content_hash,
                second_hash=other.content_hash,
                kind="VISUALLY_CONFIRMED_TRANSFORMED_PHOTO",
                reason=reason,
            ),
            ConfirmedRelation(
                first_hash=old_relative.content_hash,
                second_hash=further_parent.content_hash,
                kind="VISUALLY_CONFIRMED_SHARED_LEAF_REGION",
                reason=reason,
            ),
        ),
    )
    evidence_path = tmp_path / "confirmed-conflict.json"
    evidence_path.write_text(evidence.model_dump_json(), encoding="utf-8")
    output = tmp_path / "whole-family-v2"
    repaired = repair_dataset(parent_path, evidence_path, output, version="fixture-v2")
    removed = {first.sample_id, old_relative.sample_id, further_parent.sample_id, other.sample_id}
    assert not removed & {row.sample_id for row in repaired.eligible}
    assert repaired.counts["eligible_unique_samples"] == 44
    assert repaired.counts["excluded_files"] == 6
    assert repaired.counts["excluded_unique_contents"] == 5
    assert repaired.counts["duplicate_aliases"] == 0
    assert set(parent.excluded) <= set(repaired.excluded)
    added = [entry for entry in repaired.excluded if entry not in parent.excluded]
    assert len({entry.family_id for entry in added}) == 1
    assert {entry.relative_path for entry in added} == {
        first.relative_path,
        *first.duplicate_paths,
        old_relative.relative_path,
        further_parent.relative_path,
        other.relative_path,
    }
    assert all(
        entry.reason_codes == ("CONTRADICTORY_LABEL_FAMILY", "PHASE105_NEW_CONTRADICTORY_FAMILY")
        for entry in added
    )
    assert all(
        entry.disposition == "excluded" and entry.sample_id is None
        for entry in repaired.source_inventory
        if entry.relative_path in {added_entry.relative_path for added_entry in added}
    )
    report = json.loads((output / "repair-transition.json").read_bytes())
    assert report["changed_eligibility"] is True
    assert report["changed_labels"] is False
    assert report["new_excluded_files"] == 5
    assert report["new_excluded_unique_contents"] == 4
    assert report["new_excluded_unique_by_class"] == {CLASS_LABELS[0]: 3, CLASS_LABELS[1]: 1}
    assert report["new_contradictory_family_count"] == 1
    assert report["known_relationship_audit"]["confirmed_edge_counts"] == {"both_ineligible": 2}
    verify_manifest(repaired)


def test_repair_rejects_wrong_parent_and_same_version(
    parent_index: tuple[Path, DatasetManifest],
) -> None:
    _, parent = parent_index
    evidence = evidence_for(parent)
    with pytest.raises(ValueError, match="new version"):
        repair_groups(parent, evidence, version=parent.version)
    with pytest.raises(ValueError, match="exact parent"):
        repair_groups(
            parent,
            evidence.model_copy(update={"parent_manifest_fingerprint": "e" * 64}),
            version="fixture-v2",
        )


def test_unconfirmed_candidates_cannot_be_repair_evidence(
    parent_index: tuple[Path, DatasetManifest],
) -> None:
    _, parent = parent_index
    payload = evidence_for(parent).model_dump(mode="json")
    payload["review_status"] = "CANDIDATE_NOT_CONFIRMED"
    with pytest.raises(ValidationError):
        RepairEvidence.model_validate_json(json.dumps(payload))
    payload["review_status"] = "FINAL_CONFIRMED_RELATIONS"
    payload["confirmed_edges"][0]["kind"] = "PERCEPTUAL_THRESHOLD_ONLY"
    with pytest.raises(ValidationError):
        RepairEvidence.model_validate_json(json.dumps(payload))


def test_repair_output_cannot_enter_raw_source(
    parent_index: tuple[Path, DatasetManifest], tmp_path: Path
) -> None:
    parent_path, parent = parent_index
    evidence_path = tmp_path / "confirmed.json"
    evidence_path.write_text(evidence_for(parent).model_dump_json(), encoding="utf-8")
    output = tmp_path / "immutable raw samples" / "generated-index"
    with pytest.raises(ValueError, match="outside the source"):
        repair_dataset(parent_path, evidence_path, output, version="fixture-v2")
    assert not output.exists()
