"""Compare synthetic Node upload admission with exact shared preprocessing.

No raw dataset, model, credentials or network access is used. Run using the AI
environment Python; Node's installed tsx loader is resolved from backend.
"""

from __future__ import annotations

import base64
import json
import subprocess
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

from maizedoctor_preprocessing import (
    PreprocessingConfig,
    PreprocessingError,
    SegmentationConfig,
    preprocess_image,
)
from PIL import Image, ImageCms

REPOSITORY = Path(__file__).resolve().parents[1]
CONFIG = PreprocessingConfig(segmentation=SegmentationConfig(mode="disabled"))


@dataclass(frozen=True)
class Case:
    name: str
    encoded: bytes
    media_type: str
    filename: str
    accepted: bool


def encode(image: Image.Image, image_format: str, **options: object) -> bytes:
    output = BytesIO()
    image.save(output, format=image_format, **options)
    return output.getvalue()


def fixtures() -> list[Case]:
    cases = []
    for image_format, suffix in [("PNG", "png"), ("JPEG", "jpeg"), ("WEBP", "webp")]:
        mime = f"image/{suffix}"
        filename = f"leaf.{suffix}"
        data = encode(Image.new("RGB", (32, 48), (110, 55, 20)), image_format)
        cases.extend(
            [
                Case(f"{suffix}-rgb", data, mime, filename, True),
                Case(f"{suffix}-truncated", data[:-2], mime, filename, False),
                Case(f"{suffix}-trailing", data + b"trailing", mime, filename, False),
                Case(f"{suffix}-wrong-mime", data, "image/gif", filename, False),
                Case(f"{suffix}-wrong-extension", data, mime, "leaf.exe", False),
            ]
        )
        for width, height, expected in [
            (16, 16, True),
            (16, 64, True),
            (64, 16, True),
            (1, 1, False),
            (15, 32, False),
            (32, 15, False),
        ]:
            cases.append(
                Case(
                    f"{suffix}-{width}x{height}",
                    encode(Image.new("RGB", (width, height)), image_format),
                    mime,
                    filename,
                    expected,
                )
            )
    for mode in ["L", "LA", "RGBA", "P"]:
        cases.append(
            Case(
                f"png-{mode}",
                encode(Image.new(mode, (32, 48)), "PNG"),
                "image/png",
                "leaf.png",
                True,
            )
        )
    cases.append(
        Case(
            "jpeg-CMYK",
            encode(Image.new("CMYK", (32, 48)), "JPEG"),
            "image/jpeg",
            "leaf.jpg",
            True,
        )
    )
    for orientation in [1, 6, 8, 9]:
        exif = Image.Exif()
        exif[274] = orientation
        cases.append(
            Case(
                f"jpeg-orientation-{orientation}",
                encode(Image.new("RGB", (32, 48)), "JPEG", exif=exif),
                "image/jpeg",
                "leaf.jpg",
                orientation != 9,
            )
        )
    profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    cases.append(
        Case(
            "png-valid-srgb",
            encode(Image.new("RGB", (32, 32)), "PNG", icc_profile=profile),
            "image/png",
            "leaf.png",
            True,
        )
    )
    png = bytearray(encode(Image.new("RGB", (32, 48)), "PNG"))
    png[png.index(b"IDAT") + 5] ^= 0xFF
    cases.append(Case("png-corrupt-crc", bytes(png), "image/png", "leaf.png", False))
    cases.append(
        Case(
            "png-excessive-pixels",
            encode(Image.new("RGB", (4096, 4096)), "PNG"),
            "image/png",
            "leaf.png",
            False,
        )
    )
    for image_format, suffix in [("PNG", "png"), ("WEBP", "webp")]:
        animated = encode(
            Image.new("RGB", (32, 32), "red"),
            image_format,
            save_all=True,
            append_images=[Image.new("RGB", (32, 32), "blue")],
            duration=100,
            loop=0,
        )
        cases.append(
            Case(
                f"{suffix}-animated",
                animated,
                f"image/{suffix}",
                f"leaf.{suffix}",
                False,
            )
        )
    cases.append(
        Case(
            "png-separate-default-frame",
            encode(
                Image.new("RGB", (32, 32), "red"),
                "PNG",
                save_all=True,
                default_image=True,
                append_images=[Image.new("RGB", (32, 32), "blue")],
                duration=100,
                loop=0,
            ),
            "image/png",
            "leaf.png",
            False,
        )
    )
    webp = encode(Image.new("RGB", (32, 32)), "WEBP")
    for difference in [-2, 2]:
        incorrect = bytearray(webp)
        incorrect[4:8] = (int.from_bytes(webp[4:8], "little") + difference).to_bytes(4, "little")
        cases.append(
            Case(
                f"webp-size-{difference}",
                bytes(incorrect),
                "image/webp",
                "leaf.webp",
                False,
            )
        )
    for image_format in ["GIF", "BMP", "TIFF"]:
        suffix = image_format.lower()
        cases.append(
            Case(
                f"unsupported-{suffix}",
                encode(Image.new("RGB", (32, 32)), image_format),
                f"image/{suffix}",
                f"leaf.{suffix}",
                False,
            )
        )
    cases.extend(
        [
            Case("empty", b"", "image/png", "leaf.png", False),
            Case("malformed", b"not an image", "image/png", "leaf.png", False),
            Case(
                "oversize",
                b"x" * (CONFIG.max_bytes + 1),
                "image/png",
                "leaf.png",
                False,
            ),
        ]
    )
    return cases


def main() -> None:
    cases = fixtures()
    payload = [
        {
            "name": case.name,
            "encoded": base64.b64encode(case.encoded).decode("ascii"),
            "media_type": case.media_type,
            "filename": case.filename,
        }
        for case in cases
    ]
    node = subprocess.run(
        ["node", "--import", "tsx", "../scripts/check-image-admission-contract.mjs"],
        cwd=REPOSITORY / "backend",
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        timeout=60,
        check=True,
    )
    results = json.loads(node.stdout)
    assert len(results) == len(cases)
    accepted_count = 0
    for case, result in zip(cases, results, strict=True):
        try:
            preprocess_image(
                case.encoded, CONFIG, media_type=case.media_type, filename=case.filename
            )
            shared_accepted = True
        except PreprocessingError:
            shared_accepted = False
        assert result["name"] == case.name
        assert result["accepted"] == shared_accepted == case.accepted, (
            f"Admission mismatch: {case.name}; Node={result['accepted']}, "
            f"shared={shared_accepted}, expected={case.accepted}"
        )
        if shared_accepted:
            assert result["unchanged"], "Node must preserve the original encoded bytes"
            accepted_count += 1
    print(
        json.dumps(
            {
                "status": "PASS",
                "synthetic_cases": len(cases),
                "accepted": accepted_count,
                "rejected": len(cases) - accepted_count,
                "preprocessing_version": CONFIG.preprocessing_version,
                "max_bytes": CONFIG.max_bytes,
                "max_pixels": CONFIG.max_pixels,
                "min_side": CONFIG.min_side,
                "source_dataset_used": False,
            }
        )
    )


if __name__ == "__main__":
    main()
