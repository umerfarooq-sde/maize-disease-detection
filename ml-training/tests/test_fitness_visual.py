"""Validation diagnostic safety and mechanics, with synthetic images/model only."""

import io
from pathlib import Path

import numpy as np
import pytest
import torch
from maizedoctor_preprocessing import PreprocessingConfig, SegmentationConfig
from PIL import Image
from torch import Tensor, nn

from dataset_preparation import SampleRecord, SourceProvenance, SourceReference
from fitness_visual import (
    PERTURBATIONS,
    Perturbation,
    cam_geometry,
    grad_cam,
    inverse_for_display,
    perturb_image,
    run_visual_review,
    select_visual_rows,
    source_membership,
    summarize_probes,
)
from preprocessing import preprocess_image


def sample(index: int, class_index: int = 0, versions: tuple[str, ...] = ()) -> SampleRecord:
    digest = f"{index:064x}"
    return SampleRecord(
        sample_id=digest,
        content_hash=digest,
        pixel_hash=None,
        label="synthetic",
        class_index=class_index,
        relative_path=f"synthetic/{index}.png",
        group_id=digest,
        duplicate_paths=(),
        provenance=SourceProvenance(
            references=tuple(
                SourceReference(
                    dataset_version_id=version,
                    variant="color",
                    source_class="synthetic",
                    original_name=f"{index}.png",
                    declared_origin=True,
                )
                for version in versions
            ),
            original_ids=(),
            original_uuids=(),
        ),
    )


@pytest.mark.parametrize("specification", PERTURBATIONS)
def test_probes_are_deterministic_preserve_source_and_use_shared_pipeline(
    specification: Perturbation,
) -> None:
    pixels = np.zeros((40, 48, 3), dtype=np.uint8)
    pixels[:] = (65, 115, 55)
    pixels[12:20, 14:22] = (170, 110, 65)
    before = pixels.copy()
    config = PreprocessingConfig(segmentation=SegmentationConfig(mode="disabled"))
    first = perturb_image(pixels, specification, config.background_rgb)
    assert first == perturb_image(pixels, specification, config.background_rgb)
    np.testing.assert_array_equal(pixels, before)
    result = preprocess_image(first, config)
    assert result.metadata.config_hash == config.fingerprint
    assert result.metadata.segmentation.status == "disabled"
    assert result.model_array.shape == (3, 224, 224)
    assert np.isfinite(result.model_array).all()
    with Image.open(io.BytesIO(first)) as image:
        assert image.size == (48, 40)


def test_scale_probe_shrinks_without_crop_and_uses_background() -> None:
    pixels = np.full((100, 100, 3), 40, dtype=np.uint8)
    data = perturb_image(pixels, Perturbation("scale", "scale", 0.97), (255, 255, 255))
    with Image.open(io.BytesIO(data)) as image:
        actual = np.array(image)
    assert actual.shape == pixels.shape
    np.testing.assert_array_equal(actual[0, 0], [255, 255, 255])
    np.testing.assert_array_equal(actual[50, 50], [40, 40, 40])
    with pytest.raises(ValueError, match="without cropping"):
        perturb_image(pixels, Perturbation("invalid", "scale", 1.1), (255, 255, 255))


class TinyCamModel(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.features = nn.Sequential(nn.Conv2d(3, 4, 3, padding=1), nn.ReLU())
        self.classifier = nn.Linear(4, 4)

    def forward(self, inputs: Tensor) -> Tensor:
        return self.classifier(self.features(inputs).mean(dim=(2, 3)))


def test_gradcam_is_finite_and_does_not_change_model_or_leave_hooks() -> None:
    torch.set_num_threads(2)
    model = TinyCamModel().eval()
    before = {name: value.clone() for name, value in model.state_dict().items()}
    inputs = torch.full((1, 3, 32, 32), 0.3)
    logits = model(inputs).detach()
    cam = grad_cam(model, inputs, int(logits.argmax()))
    assert cam.shape == (32, 32) and np.isfinite(cam).all()
    assert np.all(cam >= 0) and np.all(cam <= 1)
    assert not model.features[-1]._forward_hooks
    assert all(parameter.grad is None for parameter in model.parameters())
    for name, value in model.state_dict().items():
        torch.testing.assert_close(value, before[name], rtol=0, atol=0)
    torch.testing.assert_close(model(inputs), logits, rtol=0, atol=0)


def test_cam_geometry_distinguishes_area_baseline_from_semantic_truth() -> None:
    uniform = np.ones((100, 100), dtype=np.float32)
    result = cam_geometry(uniform, (10, 0, 90, 100))
    assert result["border_activation_fraction"] == pytest.approx(0.36)
    assert result["border_enrichment_vs_uniform"] == pytest.approx(1)
    assert result["letterbox_activation_fraction"] == pytest.approx(0.2)
    assert (
        cam_geometry(np.zeros_like(uniform), (0, 0, 100, 100))["border_activation_fraction"] is None
    )
    assert not any("lesion" in key or "leaf" in key for key in result)


def test_visual_selection_includes_all_errors_and_each_correct_class() -> None:
    rows = [sample(index + 1, index % 4) for index in range(12)]
    probabilities = np.full((12, 4), 0.02)
    for index, row in enumerate(rows):
        probabilities[index, row.class_index] = 0.94
    probabilities[0] = [0.01, 0.97, 0.01, 0.01]
    proxies = [
        {"brightness": float(index), "sharpness": float(index), "aspect_extremeness": 1.0}
        for index in range(12)
    ]
    selected = select_visual_rows(rows, probabilities, proxies)
    assert "misclassified" in selected[0]
    assert "wrong_confidence_ge_0.9" in selected[0]
    correct_classes = {
        rows[index].class_index
        for index, categories in selected.items()
        if "highest_confidence_correct_per_class" in categories
    }
    assert correct_classes == {0, 1, 2, 3}
    assert not any(
        "small_lesion" in category for categories in selected.values() for category in categories
    )


def test_source_identity_is_archive_membership_not_invented_field_domain() -> None:
    assert (
        source_membership(sample(1, versions=("277323/658267", "967819/1637108")))
        == "PlantVillage_color_overlap"
    )
    assert (
        source_membership(sample(2, versions=("967819/1637108",)))
        == "Corn_collection_only_origin_not_independently_verified"
    )
    assert source_membership(sample(3)) == "source_membership_unmapped"


def test_inverse_is_display_only_roundtrip() -> None:
    config = PreprocessingConfig(segmentation=SegmentationConfig(mode="disabled"))
    pixels = np.zeros((224, 224, 3), dtype=np.uint8)
    pixels[:] = (145, 92, 41)
    buffer = io.BytesIO()
    Image.fromarray(pixels).save(buffer, format="PNG")
    result = preprocess_image(buffer.getvalue(), config)
    np.testing.assert_array_equal(np.array(inverse_for_display(result.to_tensor(), config)), pixels)


def test_new_directory_outside_dataset_required_before_model_access(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source = tmp_path / "source"
    source.mkdir()
    monkeypatch.setattr("fitness_visual.load_dataset_path", lambda: source)
    for output in (source, source / "new-inside-source", tmp_path):
        with pytest.raises(ValueError, match="new output directory outside source"):
            run_visual_review(tmp_path / "missing-manifest", tmp_path / "missing-model", output)


def test_probe_comparison_uses_same_admitted_original_subset() -> None:
    labels = np.array([0, 1], dtype=np.int64)
    original = np.array([[0.9, 0.1], [0.9, 0.1]], dtype=np.float64)
    probe = np.array([[0.8, 0.2], [np.nan, np.nan]], dtype=np.float64)
    result = summarize_probes(labels, original, {"probe": probe}, ["a", "b"])["probe"]
    assert result["evaluated"] == 1 and result["admission_failures"] == 1
    assert result["matched_original_metrics"]["accuracy"] == 1
    assert result["accuracy_change_vs_matched_original"] == 0


def test_all_rejected_probe_reports_undefined_instead_of_empty_metrics() -> None:
    labels = np.array([0, 1], dtype=np.int64)
    original = np.array([[0.9, 0.1], [0.1, 0.9]], dtype=np.float64)
    result = summarize_probes(
        labels, original, {"probe": np.full_like(original, np.nan)}, ["a", "b"]
    )["probe"]
    assert result["evaluated"] == 0 and result["metrics"] is None
    assert result["matched_original_metrics"] is None and result["undefined_reason"]
