"""Exercise the internal raw-image contract and startup-owned classifier lifecycle.

All images and weights here are synthetic. Real TRAIN-only parity is verified
separately, without rerunning the frozen final test partition.
"""

import asyncio
import hashlib
import json
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path
from threading import Event

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from httpx import Response
from PIL import Image
from pydantic import SecretStr
from starlette.requests import Request

from app.api.routes.prediction import read_image
from app.config.settings import Settings
from app.main import create_app
from app.model_management.artifacts import LoadedModel, ModelStartupError
from app.utils.errors import AppError, ErrorCode
from tests.model_fixtures import ModelFixture, write_model_fixture

SERVICE_TOKEN = "test_only_" + "P" * 55
HEADERS = {"Authorization": f"Bearer {SERVICE_TOKEN}"}
MAX_IMAGE_BYTES = 5 * 1024 * 1024
CLASS_NAMES = (
    "Common_Rust",
    "Gray_Leaf_Spot",
    "Healthy",
    "Northern_Corn_Leaf_Blight",
)


def image_bytes(
    image_format: str = "JPEG",
    *,
    size: tuple[int, int] = (80, 120),
    mode: str = "RGB",
) -> bytes:
    colors = {"RGB": (42, 112, 59), "RGBA": (42, 112, 59, 128), "L": 115, "CMYK": 30}
    output = BytesIO()
    Image.new(mode, size, colors[mode]).save(output, format=image_format)
    return output.getvalue()


def settings_for(fixture: ModelFixture, **overrides: object) -> Settings:
    arguments: dict[str, object] = {
        "_env_file": None,
        "environment": "test",
        "ai_service_token": SecretStr(SERVICE_TOKEN),
        "inference_enabled": True,
        "model_path": fixture.checkpoint_path,
        "model_metadata_path": fixture.metadata_path,
        "model_metadata_sha256": fixture.metadata_sha256,
        "model_version": fixture.model_version,
        "preprocessing_version": fixture.preprocessing_version,
        "inference_threads": 2,
        "inference_max_concurrency": 1,
    }
    arguments.update(overrides)
    return Settings(**arguments)


@pytest.fixture(scope="module")
def model_fixture(tmp_path_factory: pytest.TempPathFactory) -> ModelFixture:
    return write_model_fixture(tmp_path_factory.mktemp("prediction-api-model"))


@pytest.fixture
def prediction_application(model_fixture: ModelFixture) -> FastAPI:
    return create_app(settings_for(model_fixture))


@pytest.fixture
def prediction_client(prediction_application: FastAPI) -> Iterator[TestClient]:
    with TestClient(prediction_application) as client:
        yield client


def assert_error(response: Response, status: int, code: str) -> None:
    # Keep the shared API envelope and omit arbitrary decoder/request values.
    http_response = response
    assert http_response.status_code == status
    payload = http_response.json()
    assert set(payload) == {"success", "error", "meta"}
    assert payload["success"] is False
    assert payload["error"]["code"] == code
    assert payload["meta"]["requestId"] == http_response.headers["X-Request-Id"]
    assert "Traceback" not in http_response.text
    assert SERVICE_TOKEN not in http_response.text
    assert "state_dict" not in http_response.text
    assert http_response.headers["Cache-Control"] == "no-store"


@pytest.mark.parametrize(
    "image_format,mime_type", [("JPEG", "image/jpeg"), ("PNG", "image/png"), ("WEBP", "image/webp")]
)
def test_supported_still_images_return_one_safe_prediction(
    prediction_client: TestClient, model_fixture: ModelFixture, image_format: str, mime_type: str
) -> None:
    response = prediction_client.post(
        "/api/v1/predict",
        content=image_bytes(image_format),
        headers={**HEADERS, "Content-Type": mime_type},
    )
    assert response.status_code == 200
    payload = response.json()
    assert set(payload) == {"success", "data", "meta"}
    assert payload["success"] is True
    data = payload["data"]
    assert set(data) == {
        "predictedClass",
        "confidence",
        "topProbabilities",
        "modelVersion",
        "preprocessingVersion",
        "inferenceDurationMs",
        "predictionStatus",
        "uncertaintyReason",
        "confidenceThreshold",
    }
    assert data["predictedClass"] in CLASS_NAMES
    assert 0 <= data["confidence"] <= 1
    assert data["modelVersion"] == model_fixture.model_version
    assert data["preprocessingVersion"] == model_fixture.preprocessing_version
    assert data["inferenceDurationMs"] >= 0
    assert data["predictionStatus"] == "LOW_CONFIDENCE"
    assert data["uncertaintyReason"] == "THRESHOLD_UNCONFIGURED"
    assert data["confidenceThreshold"] is None
    assert len(data["topProbabilities"]) == 4
    assert {entry["className"] for entry in data["topProbabilities"]} == set(CLASS_NAMES)
    values = [entry["probability"] for entry in data["topProbabilities"]]
    assert values == sorted(values, reverse=True)
    assert sum(values) == pytest.approx(1.0, abs=1e-6)
    assert values[0] == data["confidence"]
    assert payload["meta"] == {"requestId": response.headers["X-Request-Id"]}
    assert SERVICE_TOKEN not in response.text
    assert str(model_fixture.metadata_path) not in response.text
    assert str(model_fixture.checkpoint_path) not in response.text
    assert model_fixture.metadata_sha256 not in response.text


@pytest.mark.parametrize("class_index", range(4))
def test_literal_class_mapping_is_preserved_for_every_output_index(
    tmp_path: Path, class_index: int
) -> None:
    fixture = write_model_fixture(tmp_path, class_index=class_index)
    with TestClient(create_app(settings_for(fixture))) as client:
        response = client.post(
            "/api/v1/predict?top_k=1",
            content=image_bytes(),
            headers={**HEADERS, "Content-Type": "image/jpeg"},
        )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["predictedClass"] == CLASS_NAMES[class_index]
    assert data["confidence"] > 0.99
    assert data["topProbabilities"] == [
        {"className": CLASS_NAMES[class_index], "probability": data["confidence"]}
    ]
    # A high numeric score cannot silently replace the unapproved risk policy.
    assert data["predictionStatus"] == "LOW_CONFIDENCE"
    assert data["uncertaintyReason"] == "THRESHOLD_UNCONFIGURED"


@pytest.mark.parametrize(
    "mode,image_format,mime_type",
    [("L", "PNG", "image/png"), ("RGBA", "PNG", "image/png"), ("CMYK", "JPEG", "image/jpeg")],
)
def test_shared_color_standardization_admits_supported_image_modes(
    prediction_client: TestClient, mode: str, image_format: str, mime_type: str
) -> None:
    response = prediction_client.post(
        "/api/v1/predict",
        content=image_bytes(image_format, mode=mode),
        headers={**HEADERS, "Content-Type": mime_type},
    )
    assert response.status_code == 200


@pytest.mark.parametrize(
    "mime_type",
    ["application/octet-stream", "image/gif", "image/svg+xml", "multipart/form-data", "text/plain"],
)
def test_invalid_declared_mime_is_rejected_before_decoding(
    prediction_client: TestClient, mime_type: str
) -> None:
    response = prediction_client.post(
        "/api/v1/predict", content=image_bytes(), headers={**HEADERS, "Content-Type": mime_type}
    )
    assert_error(response, 415, "IMAGE_UNSUPPORTED")


def test_mime_header_is_required(prediction_client: TestClient) -> None:
    assert_error(
        prediction_client.post("/api/v1/predict", content=image_bytes(), headers=HEADERS),
        415,
        "IMAGE_UNSUPPORTED",
    )


def test_declared_mime_must_match_detected_image_bytes(prediction_client: TestClient) -> None:
    assert_error(
        prediction_client.post(
            "/api/v1/predict",
            content=image_bytes("PNG"),
            headers={**HEADERS, "Content-Type": "image/jpeg"},
        ),
        422,
        "IMAGE_INVALID",
    )


@pytest.mark.parametrize(
    "contents", [b"", b"\xff\xd8\xffmalformed-private-data\xff\xd9", b"\x89PNG\r\n\x1a\ncorrupt"]
)
def test_empty_and_corrupt_supported_images_fail_safely(
    prediction_client: TestClient, contents: bytes
) -> None:
    mime_type = "image/png" if contents.startswith(b"\x89PNG") else "image/jpeg"
    response = prediction_client.post(
        "/api/v1/predict", content=contents, headers={**HEADERS, "Content-Type": mime_type}
    )
    assert_error(response, 422, "IMAGE_INVALID")
    assert "malformed-private-data" not in response.text


def test_truncated_valid_image_is_rejected(prediction_client: TestClient) -> None:
    response = prediction_client.post(
        "/api/v1/predict",
        content=image_bytes()[:-2],
        headers={**HEADERS, "Content-Type": "image/jpeg"},
    )
    assert_error(response, 422, "IMAGE_INVALID")


def test_disguised_unsupported_file_is_rejected_by_signature(prediction_client: TestClient) -> None:
    output = BytesIO()
    Image.new("RGB", (60, 60)).save(output, format="GIF")
    response = prediction_client.post(
        "/api/v1/predict",
        content=output.getvalue(),
        headers={**HEADERS, "Content-Type": "image/png"},
    )
    assert_error(response, 415, "IMAGE_UNSUPPORTED")


def test_animated_png_is_not_a_still_image(prediction_client: TestClient) -> None:
    output = BytesIO()
    Image.new("RGB", (64, 64), "green").save(
        output,
        format="PNG",
        save_all=True,
        append_images=[Image.new("RGB", (64, 64), "brown")],
        duration=100,
        loop=0,
    )
    response = prediction_client.post(
        "/api/v1/predict",
        content=output.getvalue(),
        headers={**HEADERS, "Content-Type": "image/png"},
    )
    assert_error(response, 415, "IMAGE_UNSUPPORTED")


@pytest.mark.parametrize("size", [(15, 256), (256, 15), (4001, 4000)])
def test_shared_dimension_limits_are_authoritative(
    prediction_client: TestClient, size: tuple[int, int]
) -> None:
    response = prediction_client.post(
        "/api/v1/predict",
        content=image_bytes("PNG", size=size),
        headers={**HEADERS, "Content-Type": "image/png"},
    )
    assert_error(response, 422, "IMAGE_DIMENSIONS")


def test_byte_limit_rejects_excessive_declared_length(prediction_client: TestClient) -> None:
    response = prediction_client.post(
        "/api/v1/predict",
        content=image_bytes(),
        headers={
            **HEADERS,
            "Content-Type": "image/jpeg",
            "Content-Length": str(MAX_IMAGE_BYTES + 1),
        },
    )
    assert_error(response, 413, "REQUEST_TOO_LARGE")


@pytest.mark.parametrize("declared_length", [None, "3"])
def test_streamed_byte_limit_does_not_trust_content_length(
    prediction_client: TestClient, declared_length: str | None
) -> None:
    headers = {**HEADERS, "Content-Type": "image/jpeg"}
    if declared_length is not None:
        headers["Content-Length"] = declared_length
    chunks = (b"x" * 65_536 for _ in range(MAX_IMAGE_BYTES // 65_536 + 1))
    response = prediction_client.post("/api/v1/predict", content=chunks, headers=headers)
    assert_error(response, 413, "REQUEST_TOO_LARGE")


@pytest.mark.parametrize("query", ["top_k=0", "top_k=5", "top_k=nope", "unexpected=1"])
def test_invalid_query_is_rejected(prediction_client: TestClient, query: str) -> None:
    response = prediction_client.post(
        f"/api/v1/predict?{query}",
        content=image_bytes(),
        headers={**HEADERS, "Content-Type": "image/jpeg"},
    )
    assert_error(response, 422, "VALIDATION_ERROR")


@pytest.mark.parametrize(
    "authorization", [None, "Bearer incorrect-service-token", "Basic untrusted"]
)
def test_authentication_precedes_query_validation_and_image_processing(
    prediction_client: TestClient, authorization: str | None
) -> None:
    headers = {"Content-Type": "text/plain"}
    if authorization is not None:
        headers["Authorization"] = authorization
    response = prediction_client.post(
        "/api/v1/predict?top_k=0", content=b"private", headers=headers
    )
    assert_error(response, 401, "AUTHENTICATION_ERROR")
    assert response.headers["WWW-Authenticate"] == "Bearer"


def test_internal_model_health_is_authenticated_and_has_no_paths(
    prediction_client: TestClient, model_fixture: ModelFixture
) -> None:
    assert_error(prediction_client.get("/api/v1/model-health"), 401, "AUTHENTICATION_ERROR")
    response = prediction_client.get("/api/v1/model-health", headers=HEADERS)
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert payload["data"]["status"] == "ready"
    assert payload["data"]["modelVersion"] == model_fixture.model_version
    assert str(model_fixture.checkpoint_path) not in response.text
    assert str(model_fixture.metadata_path) not in response.text
    assert SERVICE_TOKEN not in response.text


def test_prediction_has_no_browser_cors_or_preflight_bypass(prediction_client: TestClient) -> None:
    response = prediction_client.options(
        "/api/v1/predict",
        headers={"Origin": "https://browser.invalid", "Access-Control-Request-Method": "POST"},
    )
    assert response.status_code in {401, 405}
    assert "Access-Control-Allow-Origin" not in response.headers
    unauthorized = prediction_client.post(
        "/api/v1/predict",
        content=image_bytes(),
        headers={"Content-Type": "image/jpeg", "Origin": "https://browser.invalid"},
    )
    assert_error(unauthorized, 401, "AUTHENTICATION_ERROR")
    assert "Access-Control-Allow-Origin" not in unauthorized.headers


def test_model_loads_once_and_repeated_inference_is_stable(model_fixture: ModelFixture) -> None:
    load_calls = 0

    def load_once(*_args: object, **_kwargs: object) -> LoadedModel:
        nonlocal load_calls
        load_calls += 1
        return model_fixture.load()

    application = create_app(settings_for(model_fixture), model_loader=load_once)
    assert load_calls == 0
    with TestClient(application) as client:
        assert load_calls == 1
        assert client.get("/health").json()["data"]["model"]["status"] == "ready"
        results = []
        for _ in range(8):
            response = client.post(
                "/api/v1/predict",
                content=image_bytes(),
                headers={**HEADERS, "Content-Type": "image/jpeg"},
            )
            assert response.status_code == 200
            result = response.json()["data"]
            result.pop("inferenceDurationMs")
            results.append(result)
        assert all(result == results[0] for result in results)
        assert load_calls == 1
    assert application.state.running is False
    with TestClient(application, raise_server_exceptions=False) as restarted:
        assert restarted.get("/health").json()["data"]["model"]["status"] == "ready"
        assert load_calls == 2  # Exactly once per actual lifespan, not per request.


def test_shutdown_clears_readiness_and_prediction_without_lifespan_is_unavailable(
    prediction_application: FastAPI,
) -> None:
    with TestClient(prediction_application) as client:
        assert client.get("/health").json()["data"]["model"]["status"] == "ready"
    with TestClient(prediction_application, raise_server_exceptions=False) as restarted:
        assert restarted.get("/health").json()["data"]["model"]["status"] == "ready"
    client = TestClient(prediction_application, raise_server_exceptions=False)
    try:
        assert client.get("/health").status_code == 503
        assert client.get("/health").json()["data"]["model"]["status"] != "ready"
        response = client.post(
            "/api/v1/predict",
            content=image_bytes(),
            headers={**HEADERS, "Content-Type": "image/jpeg"},
        )
        assert_error(response, 503, "MODEL_UNAVAILABLE")
    finally:
        client.close()


@pytest.mark.parametrize("missing", ["model_path", "model_metadata_path"])
def test_missing_artifact_fails_startup_without_private_path(
    model_fixture: ModelFixture, tmp_path: Path, missing: str
) -> None:
    private_path = tmp_path / "private-unavailable-model"
    application = create_app(settings_for(model_fixture, **{missing: private_path}))
    with pytest.raises(ModelStartupError) as failure, TestClient(application):
        pass
    assert str(private_path) not in str(failure.value)
    assert application.state.running is False


def test_corrupt_metadata_fails_cleanly_at_startup(tmp_path: Path) -> None:
    fixture = write_model_fixture(tmp_path)
    fixture.metadata_path.write_bytes(b'{"checkpoint": "private-corrupt-content"')
    application = create_app(
        settings_for(
            fixture,
            model_metadata_sha256=hashlib.sha256(fixture.metadata_path.read_bytes()).hexdigest(),
        )
    )
    with pytest.raises(ModelStartupError) as failure, TestClient(application):
        pass
    assert "private-corrupt-content" not in str(failure.value)
    assert str(fixture.metadata_path) not in str(failure.value)
    assert application.state.running is False


def test_preprocessing_metadata_mismatch_fails_startup(tmp_path: Path) -> None:
    fixture = write_model_fixture(tmp_path)
    metadata = json.loads(fixture.metadata_path.read_bytes())
    metadata["input"]["normalization"]["mean"] = [0.1, 0.2, 0.3]
    fixture.metadata_path.write_text(json.dumps(metadata), encoding="utf-8")
    application = create_app(
        settings_for(
            fixture,
            model_metadata_sha256=hashlib.sha256(fixture.metadata_path.read_bytes()).hexdigest(),
        )
    )
    with pytest.raises(ModelStartupError), TestClient(application):
        pass
    assert application.state.running is False


def test_local_concurrency_is_bounded_and_busy_responses_are_explicit(
    prediction_client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    import app.inference.service as service_module

    original = service_module.preprocess_image
    entered = Event()
    release = Event()

    def hold_first(*args: object, **kwargs: object) -> object:
        entered.set()
        assert release.wait(timeout=20), "Concurrent request test did not release preprocessing."
        return original(*args, **kwargs)

    monkeypatch.setattr(service_module, "preprocess_image", hold_first)
    contents = image_bytes()

    def predict() -> Response:
        return prediction_client.post(
            "/api/v1/predict",
            content=contents,
            headers={**HEADERS, "Content-Type": "image/jpeg"},
        )

    with ThreadPoolExecutor(max_workers=6) as executor:
        first = executor.submit(predict)
        assert entered.wait(timeout=10)
        waiting = [executor.submit(predict) for _ in range(5)]
        try:
            for future in waiting:
                assert_error(future.result(timeout=10), 503, "INFERENCE_BUSY")
        finally:
            release.set()
        assert first.result(timeout=10).status_code == 200
    assert predict().status_code == 200  # Slot is released.


@pytest.mark.parametrize("length", ["-1", "nonsense", "1,2", "0" * 5000])
def test_invalid_content_length_is_safe_validation_error(
    prediction_client: TestClient, length: str
) -> None:
    response = prediction_client.post(
        "/api/v1/predict",
        content=image_bytes(),
        headers={**HEADERS, "Content-Type": "image/jpeg", "Content-Length": length},
    )
    assert_error(response, 422, "VALIDATION_ERROR")


def test_upload_reader_has_a_real_deadline() -> None:
    async def slow_receive() -> dict[str, object]:
        await asyncio.sleep(10)
        return {"type": "http.request", "body": b"", "more_body": False}

    request = Request(
        {"type": "http", "headers": [(b"content-type", b"image/jpeg")]},
        receive=slow_receive,
    )
    with pytest.raises(AppError) as failure:
        asyncio.run(read_image(request, MAX_IMAGE_BYTES, 0.01))
    assert failure.value.code == ErrorCode.REQUEST_TIMEOUT


def test_content_type_parameters_are_normalized_and_encoded_bodies_rejected(
    prediction_client: TestClient,
) -> None:
    assert (
        prediction_client.post(
            "/api/v1/predict",
            content=image_bytes("PNG"),
            headers={**HEADERS, "Content-Type": "IMAGE/PNG; charset=binary"},
        ).status_code
        == 200
    )
    response = prediction_client.post(
        "/api/v1/predict",
        content=image_bytes(),
        headers={**HEADERS, "Content-Type": "image/jpeg", "Content-Encoding": "gzip"},
    )
    assert_error(response, 415, "IMAGE_UNSUPPORTED")


def test_duplicate_mime_header_is_rejected(prediction_client: TestClient) -> None:
    response = prediction_client.post(
        "/api/v1/predict",
        content=image_bytes(),
        headers=[*HEADERS.items(), ("Content-Type", "image/jpeg"), ("Content-Type", "image/png")],
    )
    assert_error(response, 415, "IMAGE_UNSUPPORTED")


def test_default_inference_without_artifacts_fails_and_unconfigured_token_fails(
    model_fixture: ModelFixture,
) -> None:
    with (
        pytest.raises(ModelStartupError, match="MODEL_CONFIGURATION_INCOMPLETE"),
        TestClient(
            create_app(
                Settings(
                    _env_file=None, environment="test", ai_service_token=SecretStr(SERVICE_TOKEN)
                )
            )
        ),
    ):
        pass
    with (
        pytest.raises(ModelStartupError, match="SERVICE_AUTHENTICATION_REQUIRED"),
        TestClient(create_app(settings_for(model_fixture, ai_service_token=SecretStr("")))),
    ):
        pass
