"""Opt-in local artifacts for inspecting foreground/lesion preservation."""

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from maizedoctor_preprocessing.config import PreprocessingConfig, load_config
from maizedoctor_preprocessing.errors import ErrorCode, PreprocessingError
from maizedoctor_preprocessing.pipeline import preprocess_file
from maizedoctor_preprocessing.types import PreprocessingResult


def write_debug_bundle(
    result: PreprocessingResult, destination: Path, config: PreprocessingConfig
) -> Path:
    """Never overwrite an existing directory; output contains sensitive image content."""
    if result.metadata.config_hash != config.fingerprint:
        raise PreprocessingError(ErrorCode.INVALID_CONFIGURATION)
    try:
        destination.mkdir(parents=True, exist_ok=False)
        rgb = Image.fromarray(result.standardized_rgb)
        mask = (
            np.ones(result.standardized_rgb.shape[:2], dtype=np.bool_)
            if result.foreground_mask is None
            else result.foreground_mask
        )
        mask_image = Image.fromarray(mask.astype(np.uint8) * 255)
        overlay = rgb.copy()
        tint = Image.new("RGB", rgb.size, (40, 100, 220))
        selected = Image.composite(Image.blend(rgb, tint, 0.25), rgb, mask_image)
        overlay.paste(selected)
        left, top, right, bottom = result.metadata.crop_bounds
        ImageDraw.Draw(overlay).rectangle(
            (left, top, right - 1, bottom - 1), outline=(230, 140, 0), width=2
        )
        panels = [
            ("standardized", rgb),
            ("mask (full frame if fallback)", mask_image.convert("RGB")),
            ("mask overlay / crop", overlay),
            ("cropped / background removed", Image.fromarray(result.cropped_rgb)),
            ("letterboxed RGB", Image.fromarray(result.prepared_rgb)),
        ]
        sheet = Image.new("RGB", (3 * 320, 2 * 352), (245, 245, 245))
        draw = ImageDraw.Draw(sheet)
        for index, (label, panel) in enumerate(panels):
            panel.thumbnail((312, 312), Image.Resampling.BILINEAR)
            x, y = (index % 3) * 320, (index // 3) * 352
            draw.text((x + 4, y + 4), label, fill=(20, 20, 20))
            sheet.paste(panel, (x + (320 - panel.width) // 2, y + 32 + (312 - panel.height) // 2))
        draw.text((644, 356), f"status: {result.metadata.segmentation.status}", fill=(20, 20, 20))
        draw.text((644, 378), f"method: {result.metadata.segmentation.method}", fill=(20, 20, 20))
        draw.text(
            (644, 400), f"version: {result.metadata.preprocessing_version}", fill=(20, 20, 20)
        )
        Image.fromarray(result.standardized_rgb).save(destination / "standardized.png")
        mask_image.save(destination / "mask.png")
        Image.fromarray(result.prepared_rgb).save(destination / "prepared.png")
        sheet.save(destination / "contact-sheet.png")
        metadata = {
            "configuration": config.model_dump(mode="json"),
            "result": asdict(result.metadata),
        }
        (destination / "metadata.json").write_text(
            json.dumps(metadata, indent=2, allow_nan=False) + "\n", encoding="utf-8"
        )
        return destination
    except OSError:
        raise PreprocessingError(ErrorCode.DEBUG_OUTPUT_UNAVAILABLE) from None


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspect shared preprocessing on one local image")
    parser.add_argument("image", type=Path)
    parser.add_argument("--output", type=Path, required=True, help="New local debug directory")
    parser.add_argument("--config", type=Path, help="Versioned JSON configuration")
    args = parser.parse_args()
    try:
        config = load_config(args.config) if args.config else PreprocessingConfig()
        result = preprocess_file(args.image, config)
        write_debug_bundle(result, args.output, config)
    except PreprocessingError as error:
        print(
            json.dumps(
                {"success": False, "error": {"code": error.code.value, "message": str(error)}}
            ),
            file=sys.stderr,
        )
        raise SystemExit(1) from None
    print(
        json.dumps(
            {
                "success": True,
                "preprocessing_version": config.preprocessing_version,
                "config_hash": config.fingerprint,
                "segmentation": asdict(result.metadata.segmentation),
            }
        )
    )
