"""Serving imports the exact shared callables, without an inference endpoint."""

from maizedoctor_preprocessing import PreprocessingConfig, preprocess_file, preprocess_image

from app import preprocessing


def test_serving_uses_shared_public_api() -> None:
    assert preprocessing.PreprocessingConfig is PreprocessingConfig
    assert preprocessing.preprocess_image is preprocess_image
    assert preprocessing.preprocess_file is preprocess_file
