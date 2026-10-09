"""Bounded CPU inference using the same configured preprocessing as training."""

import math
from threading import BoundedSemaphore
from time import perf_counter

import torch
from maizedoctor_preprocessing.errors import ErrorCode as PreprocessingErrorCode
from maizedoctor_preprocessing.errors import PreprocessingError

from app.model_management.artifacts import LoadedModel
from app.preprocessing import preprocess_image
from app.schemas.prediction import (
    ClassProbability,
    PredictionData,
    PredictionStatus,
    UncertaintyReason,
)
from app.utils.errors import AppError, ErrorCode

_IMAGE_ERROR_CODES = {
    PreprocessingErrorCode.INVALID_INPUT,
    PreprocessingErrorCode.INVALID_IMAGE,
    PreprocessingErrorCode.FORMAT_MISMATCH,
    PreprocessingErrorCode.INVALID_COLOR_PROFILE,
}


def _image_error(code: PreprocessingErrorCode) -> ErrorCode:
    if code == PreprocessingErrorCode.IMAGE_TOO_LARGE:
        return ErrorCode.REQUEST_TOO_LARGE
    if code == PreprocessingErrorCode.INVALID_DIMENSIONS:
        return ErrorCode.IMAGE_DIMENSIONS
    if code in {
        PreprocessingErrorCode.UNSUPPORTED_FORMAT,
        PreprocessingErrorCode.ANIMATED_IMAGE,
    }:
        return ErrorCode.IMAGE_UNSUPPORTED
    if code in _IMAGE_ERROR_CODES:
        return ErrorCode.IMAGE_INVALID
    return ErrorCode.PREPROCESSING_FAILED


class InferenceService:
    """Own one startup-loaded model; concurrent excess requests fail without queuing."""

    def __init__(self, loaded: LoadedModel, *, max_concurrency: int = 1) -> None:
        if type(max_concurrency) is not int or max_concurrency < 1:
            raise ValueError("Inference concurrency must be a positive integer")
        if loaded.model.training:
            raise ValueError("Inference requires an evaluation-mode model")
        self._loaded = loaded
        self._slots = BoundedSemaphore(max_concurrency)

    @property
    def loaded_model(self) -> LoadedModel:
        return self._loaded

    def predict(
        self,
        data: bytes,
        *,
        mime_type: str,
        top_k: int = 4,
        filename: str | None = None,
    ) -> PredictionData:
        if type(top_k) is not int or not 1 <= top_k <= len(self._loaded.class_names):
            raise AppError(ErrorCode.VALIDATION_ERROR)
        if not self._slots.acquire(blocking=False):
            raise AppError(ErrorCode.INFERENCE_BUSY)
        started_at = perf_counter()
        try:
            tensor = self._prepare(data, mime_type=mime_type, filename=filename)
            probabilities = self._probabilities(tensor)
            # Preserve class-index order for exact probability ties.
            ordered = sorted(
                range(len(probabilities)), key=lambda index: (-probabilities[index], index)
            )
            predicted_index = ordered[0]
            confidence = probabilities[predicted_index]
            threshold = self._loaded.confidence_threshold
            status: PredictionStatus
            reason: UncertaintyReason | None
            if threshold is None:
                status = "LOW_CONFIDENCE"
                reason = "THRESHOLD_UNCONFIGURED"
            elif confidence < threshold:
                status = "LOW_CONFIDENCE"
                reason = "BELOW_VALIDATION_THRESHOLD"
            else:
                status = "CONFIDENT"
                reason = None
            return PredictionData(
                predicted_class=self._loaded.class_names[predicted_index],
                confidence=confidence,
                top_probabilities=[
                    ClassProbability(
                        class_name=self._loaded.class_names[index], probability=probabilities[index]
                    )
                    for index in ordered[:top_k]
                ],
                model_version=self._loaded.model_version,
                preprocessing_version=self._loaded.preprocessing_version,
                inference_duration_ms=(perf_counter() - started_at) * 1000,
                prediction_status=status,
                uncertainty_reason=reason,
                confidence_threshold=threshold,
            )
        finally:
            self._slots.release()

    def _prepare(self, data: bytes, *, mime_type: str, filename: str | None) -> torch.Tensor:
        try:
            prepared = preprocess_image(
                data, self._loaded.config, media_type=mime_type, filename=filename
            )
            if (
                prepared.metadata.preprocessing_version != self._loaded.preprocessing_version
                or prepared.metadata.config_hash != self._loaded.config.fingerprint
            ):
                raise AppError(ErrorCode.PREPROCESSING_FAILED)
            return prepared.to_tensor().unsqueeze(0)
        except PreprocessingError as error:
            raise AppError(_image_error(error.code)) from None
        except AppError:
            raise
        except Exception:
            raise AppError(ErrorCode.PREPROCESSING_FAILED) from None

    def _probabilities(self, tensor: torch.Tensor) -> list[float]:
        try:
            with torch.inference_mode():
                output: object = self._loaded.model(tensor)
                if (
                    not isinstance(output, torch.Tensor)
                    or output.shape != (1, len(self._loaded.class_names))
                    or not output.is_floating_point()
                    or not bool(torch.isfinite(output).all())
                ):
                    raise AppError(ErrorCode.INFERENCE_FAILED)
                values = torch.softmax(output / self._loaded.calibration_temperature, dim=1)
                probabilities = [float(value.item()) for value in values[0].unbind()]
        except AppError:
            raise
        except Exception:
            raise AppError(ErrorCode.INFERENCE_FAILED) from None
        if any(
            not math.isfinite(value) or not 0 <= value <= 1 for value in probabilities
        ) or not math.isclose(sum(probabilities), 1.0, abs_tol=1e-6):
            raise AppError(ErrorCode.INFERENCE_FAILED)
        return probabilities
