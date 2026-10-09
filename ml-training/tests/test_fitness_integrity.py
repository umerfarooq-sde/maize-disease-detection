"""Integrity failures remain visible without editing or re-splitting real images."""

from collections.abc import Mapping
from pathlib import Path

import pytest

from dataset_inventory import file_digest
from dataset_preparation import SampleRecord, SourceProvenance, SplitName
from fitness_integrity import relationship_audit, verify_artifact_hashes


def sample(number: int, *, group: int | None = None, original: str = "") -> SampleRecord:
    digest = f"{number:064x}"
    return SampleRecord(
        sample_id=digest,
        content_hash=digest,
        pixel_hash=f"{number + 1000:064x}",
        label="Common_Rust",
        class_index=0,
        relative_path=f"Common_Rust/image-{number}.jpg",
        group_id=f"{number if group is None else group:064x}",
        duplicate_paths=(),
        provenance=SourceProvenance(
            references=(),
            original_ids=(original,) if original else (),
            original_uuids=(original,) if original else (),
        ),
    )


def partitions(
    train: tuple[SampleRecord, ...] = (sample(1),),
    validation: tuple[SampleRecord, ...] = (sample(2),),
    test: tuple[SampleRecord, ...] = (sample(3),),
) -> Mapping[SplitName, tuple[SampleRecord, ...]]:
    return {"train": train, "validation": validation, "test": test}


def test_known_edges_in_one_partition_and_excluded_families_are_distinct() -> None:
    first, second = sample(1, group=1), sample(4, group=1)
    report = relationship_audit(
        partitions(train=(first, second)),
        confirmed_edges=((first.content_hash, second.content_hash), ("5" * 64, "6" * 64)),
        excluded_contents=("5" * 64,),
    )
    assert report["known_relationships_disjoint"] is True
    assert report["eligible_groups"] == 3
    assert report["confirmed_edge_counts"] == {"same_partition": 1, "both_ineligible": 1}


@pytest.mark.parametrize("attribute", ["group_id", "pixel_hash", "relative_path"])
def test_cross_split_identity_detected(attribute: str) -> None:
    first, second = sample(1), sample(2)
    second = second.model_copy(update={attribute: getattr(first, attribute)})
    report = relationship_audit(partitions(validation=(second,)))
    assert report["known_relationships_disjoint"] is False
    overlaps = report["pairwise_intersections"]
    assert isinstance(overlaps, dict)
    assert overlaps["train/validation"] == {
        "sample_id": 0,
        "content_hash": 0,
        "pixel_hash": int(attribute == "pixel_hash"),
        "group_id": int(attribute == "group_id"),
        "original_id": 0,
        "original_uuid": 0,
        "relative_path": int(attribute == "relative_path"),
    }


def test_recovered_parent_uuid_and_alias_detected_without_content_overlap() -> None:
    first, second = sample(1, original="original-photo"), sample(2, original="original-photo")
    second = second.model_copy(update={"duplicate_paths": (first.relative_path,)})
    report = relationship_audit(partitions(validation=(second,), train=(first,)))
    assert report["known_identity_overlap_count"] == 3
    assert report["known_relationships_disjoint"] is False


def test_confirmed_cross_partition_relation_and_excluded_content_leak() -> None:
    first, second = sample(1), sample(2)
    report = relationship_audit(
        partitions(),
        confirmed_edges=((first.content_hash, second.content_hash),),
        excluded_contents=(first.content_hash,),
    )
    assert report["confirmed_edge_counts"] == {"cross_partition": 1}
    assert report["excluded_contents_in_partitions"] == [first.content_hash]
    assert report["known_relationships_disjoint"] is False


def test_identical_sample_in_two_partitions_detected() -> None:
    report = relationship_audit(partitions(validation=(sample(1),)))
    assert report["known_identity_overlap_count"] == 5
    assert report["known_relationships_disjoint"] is False


def test_repeated_sample_within_partition_and_missing_partition_rejected() -> None:
    with pytest.raises(ValueError, match="repeated"):
        relationship_audit(partitions(train=(sample(1), sample(1))))
    with pytest.raises(ValueError, match="exactly"):
        relationship_audit({"train": (sample(1),)})


def test_cross_label_group_is_reported_even_if_same_partition() -> None:
    second = sample(4, group=1).model_copy(update={"label": "Gray_Leaf_Spot", "class_index": 1})
    report = relationship_audit(partitions(train=(sample(1), second)))
    assert report["mixed_label_group_ids"] == [sample(1).group_id]
    assert report["known_relationships_disjoint"] is False


def test_artifact_integrity_verifies_bytes_and_rejects_modification(tmp_path: Path) -> None:
    path = tmp_path / "checkpoint.pt"
    path.write_bytes(b"immutable checkpoint fixture")
    expected = {path.name: file_digest(path)}
    assert verify_artifact_hashes(tmp_path, expected) == 1
    path.write_bytes(b"different checkpoint")
    with pytest.raises(ValueError, match="pinned artifact"):
        verify_artifact_hashes(tmp_path, expected)


@pytest.mark.parametrize("relative", ["../private", "C:/private", "/private", "part\\private"])
def test_artifact_references_cannot_escape_directory(tmp_path: Path, relative: str) -> None:
    with pytest.raises(ValueError, match="safe relative"):
        verify_artifact_hashes(tmp_path, {relative: "1" * 64})
