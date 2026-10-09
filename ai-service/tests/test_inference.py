"""Exercise inference with controlled logits and the real approved shared transform."""

import hashlib
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from io import BytesIO
from pathlib import Path
from threading import Event, Lock

import numpy as np
import pytest
import torch
from maizedoctor_preprocessing import load_config, preprocess_image
from PIL import Image
from pydantic import ValidationError
from torch import nn

from app.inference.service import InferenceService
from app.model_management.artifacts import LoadedModel
from app.schemas.prediction import ClassProbability, PredictionData
from app.utils.errors import AppError, ErrorCode

REPOSITORY = Path(__file__).resolve().parents[2]
CONFIGURATION = REPOSITORY / "ml-training/manifests/maize-research-20261008-v2/preprocessing.json"
CLASS_NAMES = ("Common_Rust", "Gray_Leaf_Spot", "Healthy", "Northern_Corn_Leaf_Blight")


def encode(image: Image.Image, image_format: str = "PNG") -> bytes:
    output = BytesIO()
    image.save(output, format=image_format)
    return output.getvalue()


class ControlledModel(nn.Module):
    def __init__(self, logits: tuple[float, float, float, float]) -> None:
        super().__init__()
        self.register_buffer("logits", torch.tensor(logits, dtype=torch.float32))
        self.last_input: torch.Tensor | None = None
        self.calls = 0
        self.saw_inference_mode = False

    def forward(self, tensor: torch.Tensor) -> torch.Tensor:
        self.calls += 1
        self.last_input = tensor.clone()
        self.saw_inference_mode = torch.is_inference_mode_enabled()
        return self.logits.unsqueeze(0)


def loaded_model(
    model: nn.Module | None = None,
    *,
    threshold: float | None = None,
    temperature: float = 1.0,
) -> LoadedModel:
    network = model if model is not None else ControlledModel((0.0, 0.0, 5.0, 0.0))
    return LoadedModel(
        model=network.eval(),
        config=load_config(CONFIGURATION),
        class_names=CLASS_NAMES,
        model_version="mobilenet-v3-small-v2-20261009",
        preprocessing_version="1.0.0",
        checkpoint_sha256="a" * 64,
        manifest_fingerprint="b" * 64,
        validation_predictions_sha256="c" * 64,
        calibration_temperature=temperature,
        confidence_threshold=threshold,
    )


@pytest.fixture
def png() -> bytes:
    return encode(Image.new("RGB", (48, 80), (112, 140, 30)))


@pytest.mark.parametrize("predicted_index", range(4))
def test_each_literal_class_retains_training_index_and_default_uncertainty(
    png: bytes, predicted_index: int
) -> None:
    logits = tuple(7.0 if index == predicted_index else -1.0 for index in range(4))
    service = InferenceService(loaded_model(ControlledModel(logits)))
    result = service.predict(png, mime_type="image/png")
    assert result.predicted_class == CLASS_NAMES[predicted_index]
    assert result.confidence > 0.99
    assert result.prediction_status == "LOW_CONFIDENCE"
    assert result.uncertainty_reason == "THRESHOLD_UNCONFIGURED"
    assert result.confidence_threshold is None
    assert result.top_probabilities[0].class_name == result.predicted_class
    assert result.top_probabilities[0].probability == result.confidence
    assert sum(row.probability for row in result.top_probabilities) == pytest.approx(1.0)
    assert result.model_version == "mobilenet-v3-small-v2-20261009"
    assert result.preprocessing_version == "1.0.0"
    assert result.inference_duration_ms > 0
    encoded = result.model_dump(mode="json", by_alias=True)
    assert encoded["predictionStatus"] == "LOW_CONFIDENCE"
    assert encoded["topProbabilities"][0]["className"] == CLASS_NAMES[predicted_index]
    assert "checkpoint" not in json.dumps(encoded)
    assert "manifest" not in json.dumps(encoded)


@pytest.mark.parametrize(
    ("threshold", "status", "reason"),
    [
        (0.250001, "LOW_CONFIDENCE", "BELOW_VALIDATION_THRESHOLD"),
        (0.25, "CONFIDENT", None),
        (None, "LOW_CONFIDENCE", "THRESHOLD_UNCONFIGURED"),
    ],
)
def test_configured_threshold_boundary_and_unconfigured_policy(
    png: bytes, threshold: float | None, status: str, reason: str | None
) -> None:
    service = InferenceService(
        loaded_model(ControlledModel((0.0, 0.0, 0.0, 0.0)), threshold=threshold)
    )
    result = service.predict(png, mime_type="image/png", top_k=2)
    assert result.confidence == 0.25
    assert result.predicted_class == CLASS_NAMES[0]
    assert [row.class_name for row in result.top_probabilities] == list(CLASS_NAMES[:2])
    assert result.prediction_status == status
    assert result.uncertainty_reason == reason


def test_temperature_scales_probabilities_without_changing_class(png: bytes) -> None:
    network = ControlledModel((0.0, 0.0, 5.0, 0.0))
    raw = InferenceService(loaded_model(network)).predict(png, mime_type="image/png")
    scaled = InferenceService(loaded_model(network, temperature=2.0)).predict(
        png, mime_type="image/png"
    )
    assert scaled.predicted_class == raw.predicted_class
    assert 0.25 < scaled.confidence < raw.confidence


@pytest.mark.parametrize("top_k", [0, 5, -1, True, 1.5])
def test_invalid_top_k_rejected_before_preprocessing(png: bytes, top_k: int) -> None:
    network = ControlledModel((0.0, 0.0, 5.0, 0.0))
    with pytest.raises(AppError) as caught:
        InferenceService(loaded_model(network)).predict(png, mime_type="image/png", top_k=top_k)
    assert caught.value.code == ErrorCode.VALIDATION_ERROR
    assert network.calls == 0


@pytest.mark.parametrize(
    ("image_format", "mime_type", "filename"),
    [
        ("JPEG", "image/jpeg", "leaf.jpg"),
        ("PNG", "image/png", "leaf.png"),
        ("WEBP", "image/webp", "leaf.webp"),
    ],
)
def test_admitted_formats_have_exact_shared_tensor_parity(
    image_format: str, mime_type: str, filename: str
) -> None:
    data = encode(Image.new("RGB", (80, 32), (133, 60, 21)), image_format)
    network = ControlledModel((0.0, 0.0, 5.0, 0.0))
    loaded = loaded_model(network)
    InferenceService(loaded).predict(data, mime_type=mime_type, filename=filename)
    expected = (
        preprocess_image(data, loaded.config, media_type=mime_type, filename=filename)
        .to_tensor()
        .unsqueeze(0)
    )
    assert loaded.config.fingerprint == (
        "b142e59f458d27a2d3fddbfc86c2f2f802670ab4909f1275babbef92de9cb5c8"
    )
    assert network.last_input is not None
    assert torch.equal(network.last_input, expected)
    assert network.last_input.dtype == torch.float32
    assert network.last_input.shape == (1, 3, 224, 224)


@pytest.mark.parametrize("mode", ["L", "LA", "RGBA", "CMYK"])
def test_color_modes_use_shared_standardization(mode: str) -> None:
    image_format = "JPEG" if mode == "CMYK" else "PNG"
    mime_type = "image/jpeg" if mode == "CMYK" else "image/png"
    data = encode(Image.new(mode, (32, 40)), image_format)
    network = ControlledModel((0.0, 0.0, 5.0, 0.0))
    loaded = loaded_model(network)
    InferenceService(loaded).predict(data, mime_type=mime_type)
    expected = preprocess_image(data, loaded.config, media_type=mime_type).to_tensor()
    assert network.last_input is not None
    assert torch.equal(network.last_input[0], expected)


def test_phase10_training_dataset_and_serving_tensors_are_identical(
    tmp_path: Path, png: bytes
) -> None:
    source = tmp_path / "synthetic.png"
    source.write_bytes(png)
    destination = tmp_path / "training-tensor.npy"
    worker = """
import hashlib
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0, sys.argv[1])
from dataset_preparation import SampleRecord, SourceProvenance
from maizedoctor_preprocessing import load_config
from training_data import MaizeDataset
source = Path(sys.argv[2])
digest = hashlib.sha256(source.read_bytes()).hexdigest()
row = SampleRecord(sample_id=digest, content_hash=digest, pixel_hash=None,
    label="Healthy", class_index=2, relative_path=source.name, group_id=digest,
    duplicate_paths=(), provenance=SourceProvenance(references=(), original_ids=(),
    original_uuids=()))
dataset = MaizeDataset([row], load_config(Path(sys.argv[3])), split="validation",
    augment=False, dataset_root=source.parent)
tensor, label, sample_id = dataset[0]
assert label == 2 and sample_id == digest
np.save(sys.argv[4], tensor.numpy(), allow_pickle=False)
"""
    subprocess.run(
        [
            sys.executable,
            "-c",
            worker,
            str(REPOSITORY / "ml-training"),
            str(source),
            str(CONFIGURATION),
            str(destination),
        ],
        check=True,
        capture_output=True,
        text=True,
        timeout=45,
    )
    network = ControlledModel((0.0, 0.0, 5.0, 0.0))
    InferenceService(loaded_model(network)).predict(png, mime_type="image/png")
    assert network.last_input is not None
    expected = torch.from_numpy(np.load(destination, allow_pickle=False))
    assert torch.equal(network.last_input[0], expected)
    assert hashlib.sha256(network.last_input[0].numpy().tobytes()).hexdigest() == (
        hashlib.sha256(expected.numpy().tobytes()).hexdigest()
    )


@pytest.mark.parametrize(
    ("data", "mime_type", "expected"),
    [
        (b"", "image/png", ErrorCode.IMAGE_INVALID),
        (b"private malformed input", "image/png", ErrorCode.IMAGE_UNSUPPORTED),
        (b"\xff\xd8\xffcorrupt", "image/jpeg", ErrorCode.IMAGE_INVALID),
        (b"RIFF\x04\x00\x00\x00WEBP", "image/webp", ErrorCode.IMAGE_INVALID),
    ],
)
def test_malformed_images_fail_safely_without_model_call(
    data: bytes, mime_type: str, expected: ErrorCode
) -> None:
    network = ControlledModel((0.0, 0.0, 5.0, 0.0))
    with pytest.raises(AppError) as caught:
        InferenceService(loaded_model(network)).predict(data, mime_type=mime_type)
    assert caught.value.code == expected
    assert "private" not in str(caught.value)
    assert network.calls == 0


@pytest.mark.parametrize("mime_type", ["image/jpeg", "text/plain", "image/PNG"])
def test_mime_mismatch_is_rejected(png: bytes, mime_type: str) -> None:
    with pytest.raises(AppError) as caught:
        InferenceService(loaded_model()).predict(png, mime_type=mime_type)
    assert caught.value.code == ErrorCode.IMAGE_INVALID


def test_filename_extension_mismatch_is_rejected(png: bytes) -> None:
    with pytest.raises(AppError) as caught:
        InferenceService(loaded_model()).predict(
            png, mime_type="image/png", filename="private-name.jpg"
        )
    assert caught.value.code == ErrorCode.IMAGE_INVALID
    assert "private-name" not in str(caught.value)


@pytest.mark.parametrize("image_format", ["BMP", "GIF", "TIFF"])
def test_unsupported_formats_are_rejected(image_format: str) -> None:
    data = encode(Image.new("RGB", (32, 32)), image_format)
    with pytest.raises(AppError) as caught:
        InferenceService(loaded_model()).predict(data, mime_type="image/png")
    assert caught.value.code == ErrorCode.IMAGE_UNSUPPORTED


def test_animated_png_is_rejected() -> None:
    buffer = BytesIO()
    image = Image.new("RGB", (32, 32), (20, 40, 60))
    image.save(
        buffer, format="PNG", save_all=True, append_images=[Image.new("RGB", (32, 32))], duration=20
    )
    with pytest.raises(AppError) as caught:
        InferenceService(loaded_model()).predict(buffer.getvalue(), mime_type="image/png")
    assert caught.value.code == ErrorCode.IMAGE_UNSUPPORTED


@pytest.mark.parametrize("size", [(15, 32), (32, 15), (4001, 4000)])
def test_too_small_and_excessive_dimensions_fail_before_model(size: tuple[int, int]) -> None:
    data = encode(Image.new("L", size))
    network = ControlledModel((0.0, 0.0, 5.0, 0.0))
    with pytest.raises(AppError) as caught:
        InferenceService(loaded_model(network)).predict(data, mime_type="image/png")
    assert caught.value.code == ErrorCode.IMAGE_DIMENSIONS
    assert network.calls == 0


def test_minimum_dimensions_are_admitted() -> None:
    data = encode(Image.new("L", (16, 16)))
    assert InferenceService(loaded_model()).predict(data, mime_type="image/png").confidence > 0


def test_excessive_encoded_size_is_rejected() -> None:
    with pytest.raises(AppError) as caught:
        InferenceService(loaded_model()).predict(
            b"x" * (5 * 1024 * 1024 + 1), mime_type="image/png"
        )
    assert caught.value.code == ErrorCode.REQUEST_TOO_LARGE


def test_repeated_inference_preserves_weights_eval_and_uses_inference_mode(png: bytes) -> None:
    network = ControlledModel((0.0, 0.0, 5.0, 0.0))
    service = InferenceService(loaded_model(network))
    before = {name: value.clone() for name, value in network.state_dict().items()}
    results = [service.predict(png, mime_type="image/png") for _ in range(3)]
    assert network.calls == 3
    assert network.saw_inference_mode is True
    assert network.training is False
    assert all(torch.equal(before[name], value) for name, value in network.state_dict().items())
    assert all(result.confidence == results[0].confidence for result in results)
    assert all(result.top_probabilities == results[0].top_probabilities for result in results)


def test_failed_preprocessing_releases_slot_and_hides_internal_exception(
    monkeypatch: pytest.MonkeyPatch, png: bytes
) -> None:
    service = InferenceService(loaded_model())
    original = preprocess_image

    def failed(*args: object, **kwargs: object) -> object:
        raise RuntimeError("private server path and decoder traceback")

    monkeypatch.setattr("app.inference.service.preprocess_image", failed)
    with pytest.raises(AppError) as caught:
        service.predict(png, mime_type="image/png")
    assert caught.value.code == ErrorCode.PREPROCESSING_FAILED
    assert "private" not in str(caught.value)
    monkeypatch.setattr("app.inference.service.preprocess_image", original)
    assert service.predict(png, mime_type="image/png").confidence > 0


@pytest.mark.parametrize("output_kind", ["shape", "nan", "integer", "not-tensor", "exception"])
def test_invalid_model_outputs_fail_safely_and_release_slot(png: bytes, output_kind: str) -> None:
    class InvalidModel(nn.Module):
        def forward(self, tensor: torch.Tensor) -> object:
            if output_kind == "shape":
                return torch.zeros((1, 3))
            if output_kind == "nan":
                return torch.full((1, 4), float("nan"))
            if output_kind == "integer":
                return torch.zeros((1, 4), dtype=torch.int64)
            if output_kind == "not-tensor":
                return [0.0, 0.0, 0.0, 0.0]
            raise RuntimeError("private model failure")

    service = InferenceService(loaded_model(InvalidModel()))
    for _ in range(2):
        with pytest.raises(AppError) as caught:
            service.predict(png, mime_type="image/png")
        assert caught.value.code == ErrorCode.INFERENCE_FAILED
        assert "private" not in str(caught.value)


def test_concurrent_excess_is_rejected_while_two_loaded_model_calls_finish(png: bytes) -> None:
    started = Event()
    release = Event()
    counter_lock = Lock()

    class BlockingModel(ControlledModel):
        def forward(self, tensor: torch.Tensor) -> torch.Tensor:
            with counter_lock:
                self.calls += 1
                if self.calls == 2:
                    started.set()
            if not release.wait(timeout=10):
                raise RuntimeError("Test inference wait expired")
            return self.logits.unsqueeze(0)

    model = BlockingModel((0.0, 0.0, 5.0, 0.0))
    service = InferenceService(loaded_model(model), max_concurrency=2)
    with ThreadPoolExecutor(max_workers=6) as executor:
        first = executor.submit(service.predict, png, mime_type="image/png")
        second = executor.submit(service.predict, png, mime_type="image/png")
        try:
            assert started.wait(timeout=5)
            excess = [
                executor.submit(service.predict, png, mime_type="image/png") for _ in range(4)
            ]
            for future in excess:
                with pytest.raises(AppError) as caught:
                    future.result(timeout=5)
                assert caught.value.code == ErrorCode.INFERENCE_BUSY
        finally:
            release.set()
        assert first.result(timeout=5).predicted_class == "Healthy"
        assert second.result(timeout=5).predicted_class == "Healthy"
    assert model.calls == 2
    assert service.predict(png, mime_type="image/png").predicted_class == "Healthy"


def test_constructor_rejects_training_mode_and_invalid_concurrency() -> None:
    loaded = loaded_model()
    with pytest.raises(ValueError, match="evaluation-mode"):
        InferenceService(replace(loaded, model=loaded.model.train()))
    loaded.model.eval()
    with pytest.raises(ValueError, match="positive integer"):
        InferenceService(loaded, max_concurrency=0)


def test_response_schema_rejects_false_confidence_when_policy_unconfigured() -> None:
    with pytest.raises(ValidationError):
        PredictionData(
            predicted_class="Healthy",
            confidence=0.99,
            top_probabilities=[ClassProbability(class_name="Healthy", probability=0.99)],
            model_version="test",
            preprocessing_version="1.0.0",
            inference_duration_ms=1.0,
            prediction_status="CONFIDENT",
            uncertainty_reason=None,
            confidence_threshold=None,
        )
