"""Training imports the exact serving preprocessing, without adding augmentation."""

from maizedoctor_preprocessing import PreprocessingConfig, preprocess_file, preprocess_image

import preprocessing


def test_training_uses_shared_public_api() -> None:
    assert preprocessing.PreprocessingConfig is PreprocessingConfig
    assert preprocessing.preprocess_image is preprocess_image
    assert preprocessing.preprocess_file is preprocess_file
