"""Intake keeps originals intact and reports leakage/invalid inputs explicitly."""

from pathlib import Path

import pytest
from PIL import Image

from dataset_inventory import (
    duplicate_groups,
    infer_label,
    inspect_image,
    near_duplicate_candidates,
)
from dataset_review import comparison_configs, run_review, validate_destination


def test_literal_labels_and_existing_split_containers() -> None:
    assert infer_label(Path("Gray_Leaf_Spot/a.jpg")) == ("Gray_Leaf_Spot", None)
    assert infer_label(Path("train/Common_Rust/a.jpg")) == ("Common_Rust", "train")
    assert infer_label(Path("a.jpg")) == (None, None)
    assert infer_label(Path("test/a.jpg")) == (None, "test")


def test_duplicate_content_different_labels_and_corrupt_originals(tmp_path: Path) -> None:
    root = tmp_path / "source"
    first = root / "Literal_Label"
    second = root / "Other_Label"
    first.mkdir(parents=True)
    second.mkdir()
    Image.new("RGB", (40, 32), "brown").save(first / "one.jpg")
    (second / "copy.jpg").write_bytes((first / "one.jpg").read_bytes())
    (first / "bad.jpg").write_bytes(b"not an image")
    before = {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
    records = [inspect_image(root, p) for p in sorted(root.rglob("*.jpg"))]
    assert duplicate_groups(records) == [["Literal_Label/one.jpg", "Other_Label/copy.jpg"]]
    assert duplicate_groups(records, pixels=True) == duplicate_groups(records)
    assert [r.decode_error for r in records].count("UNREADABLE_IMAGE") == 1
    assert near_duplicate_candidates(records) == []
    assert before == {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}


def test_review_reports_bad_files_and_conflicting_labels_without_splits(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "data"
    for label in ["Class_A", "Class_B"]:
        (root / label).mkdir(parents=True)
    Image.new("RGB", (40, 32), "brown").save(root / "Class_A" / "one.jpg")
    (root / "Class_B" / "copy.jpg").write_bytes((root / "Class_A" / "one.jpg").read_bytes())
    (root / "Class_A" / "bad.jpg").write_bytes(b"broken")
    (root / "README.txt").write_text("fixture", encoding="utf-8")
    monkeypatch.setenv("DATASET_PATH", str(root))
    before = {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
    result = run_review(tmp_path / "output", samples_per_class=2)
    assert result["images"] == 3
    assert result["conflicting_exact_groups"] == [["Class_A/one.jpg", "Class_B/copy.jpg"]]
    assert result["unsupported_files"] == ["README.txt"]
    assert result["sample_count"] == 2
    assert result["source_unchanged"] is True
    assert result["split_folder_counts"] == {}
    assert before == {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
    assert (tmp_path / "output" / "samples" / "000" / "comparison.png").is_file()
    assert (tmp_path / "output" / "inventory.csv").is_file()


def test_reject_source_output_and_overwrite(tmp_path: Path) -> None:
    root = tmp_path / "source"
    root.mkdir()
    with pytest.raises(ValueError, match="outside"):
        validate_destination(root, root / "generated")
    with pytest.raises(ValueError, match="overwrite"):
        validate_destination(root, root.parent)


def test_policy_comparison_does_not_change_canonical_default() -> None:
    from preprocessing import PreprocessingConfig

    enabled, disabled = comparison_configs()
    assert enabled == PreprocessingConfig()
    assert disabled.segmentation.mode == "disabled"
    assert enabled.fingerprint != disabled.fingerprint
    assert enabled.preprocessing_version == disabled.preprocessing_version
