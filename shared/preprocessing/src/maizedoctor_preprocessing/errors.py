"""Safe failures without filenames, raw input, decoder messages or stack traces."""

from enum import StrEnum


class ErrorCode(StrEnum):
    INVALID_INPUT = "INVALID_INPUT"
    IMAGE_TOO_LARGE = "IMAGE_TOO_LARGE"
    UNSUPPORTED_FORMAT = "UNSUPPORTED_FORMAT"
    FORMAT_MISMATCH = "FORMAT_MISMATCH"
    INVALID_IMAGE = "INVALID_IMAGE"
    INVALID_DIMENSIONS = "INVALID_DIMENSIONS"
    ANIMATED_IMAGE = "ANIMATED_IMAGE"
    INVALID_COLOR_PROFILE = "INVALID_COLOR_PROFILE"
    INVALID_MASK = "INVALID_MASK"
    SEGMENTATION_UNCERTAIN = "SEGMENTATION_UNCERTAIN"
    FILE_UNAVAILABLE = "FILE_UNAVAILABLE"
    INVALID_CONFIGURATION = "INVALID_CONFIGURATION"
    DEBUG_OUTPUT_UNAVAILABLE = "DEBUG_OUTPUT_UNAVAILABLE"


MESSAGES: dict[ErrorCode, str] = {
    ErrorCode.INVALID_INPUT: "Provide nonempty encoded image bytes.",
    ErrorCode.IMAGE_TOO_LARGE: "The image exceeds the configured byte limit.",
    ErrorCode.UNSUPPORTED_FORMAT: "Only still JPEG, PNG and WebP images are supported.",
    ErrorCode.FORMAT_MISMATCH: "The image format does not match the supplied type or extension.",
    ErrorCode.INVALID_IMAGE: "The image cannot be safely decoded.",
    ErrorCode.INVALID_DIMENSIONS: "The image dimensions exceed the configured limits.",
    ErrorCode.ANIMATED_IMAGE: "Animated or multiple-frame images are unsupported.",
    ErrorCode.INVALID_COLOR_PROFILE: "The embedded color profile cannot be standardized.",
    ErrorCode.INVALID_MASK: "Provide a boolean mask matching the oriented image dimensions.",
    ErrorCode.SEGMENTATION_UNCERTAIN: "Foreground extraction is uncertain; review the image.",
    ErrorCode.FILE_UNAVAILABLE: "The input file cannot be read.",
    ErrorCode.INVALID_CONFIGURATION: "The preprocessing configuration is invalid or incompatible.",
    ErrorCode.DEBUG_OUTPUT_UNAVAILABLE: "Use a new writable directory for the debug bundle.",
}


class PreprocessingError(Exception):
    def __init__(self, code: ErrorCode) -> None:
        self.code = code
        super().__init__(MESSAGES[code])
