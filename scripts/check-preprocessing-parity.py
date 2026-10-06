"""Compare identical synthetic inputs through the two installed consumer APIs."""

import argparse
import hashlib
import json
import os
import subprocess
import sys
from dataclasses import asdict
from pathlib import Path
from tempfile import TemporaryDirectory

REPOSITORY = Path(__file__).resolve().parents[1]


def worker(component: str, fixture: Path, configuration: Path) -> None:
    import maizedoctor_preprocessing as shared

    sys.path.insert(0, str(REPOSITORY / component))
    if component == "ai-service":
        from app import preprocessing as consumer
    else:
        import preprocessing as consumer
    assert consumer.preprocess_image is shared.preprocess_image
    assert consumer.preprocess_file is shared.preprocess_file
    config = shared.load_config(configuration)
    result = consumer.preprocess_file(fixture, config)
    print(
        json.dumps(
            {
                "implementation": str(
                    Path(shared.preprocess_image.__code__.co_filename).resolve()
                ),
                "array_hash": hashlib.sha256(result.model_array.tobytes()).hexdigest(),
                "mask_hash": hashlib.sha256(
                    result.foreground_mask.tobytes()
                ).hexdigest()
                if result.foreground_mask is not None
                else None,
                "tensor_hash": hashlib.sha256(
                    result.to_tensor().numpy().tobytes()
                ).hexdigest(),
                "dtype": str(result.model_array.dtype),
                "shape": result.model_array.shape,
                "metadata": asdict(result.metadata),
            },
            sort_keys=True,
        )
    )


def check() -> None:
    from maizedoctor_preprocessing import NormalizationConfig, PreprocessingConfig
    from PIL import Image, ImageDraw

    cache = REPOSITORY / ".cache"
    cache.mkdir(exist_ok=True)
    with TemporaryDirectory(prefix="preprocessing-parity-", dir=cache) as directory:
        temporary = Path(directory).resolve()
        assert temporary.is_relative_to(cache.resolve())
        samples = []
        leaf = Image.new("RGB", (120, 240), (245, 245, 245))
        draw = ImageDraw.Draw(leaf)
        draw.ellipse((35, 20, 85, 220), fill=(50, 110, 40))
        for index, color in enumerate(
            (
                (125, 65, 20),
                (225, 195, 35),
                (120, 120, 120),
                (155, 60, 20),
                (245, 245, 245),
            )
        ):
            draw.rectangle((48, 45 + index * 28, 72, 60 + index * 28), fill=color)
        samples.append(("synthetic-lesions", leaf))
        samples.append(("synthetic-gray", leaf.convert("L")))
        alpha = Image.new("RGBA", (140, 120), (0, 0, 0, 0))
        ImageDraw.Draw(alpha).ellipse((20, 20, 120, 100), fill=(150, 80, 30, 128))
        samples.append(("synthetic-alpha", alpha))
        samples.append(
            ("synthetic-no-foreground", Image.new("RGB", (80, 80), (100, 100, 100)))
        )
        configs = (
            PreprocessingConfig(),
            PreprocessingConfig(
                target_height=160,
                target_width=96,
                normalization=NormalizationConfig(
                    mean=(0.4, 0.5, 0.6), std=(0.2, 0.3, 0.4)
                ),
            ),
        )
        comparisons = 0
        for sample_name, image in samples:
            fixture = temporary / f"{sample_name}.png"
            image.save(fixture)
            for config_index, config in enumerate(configs):
                config_file = temporary / f"config-{config_index}.json"
                config_file.write_text(config.model_dump_json(), encoding="utf-8")
                results = []
                for component in ("ai-service", "ml-training"):
                    executable = (
                        REPOSITORY
                        / component
                        / ".venv"
                        / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
                    )
                    process = subprocess.run(
                        [
                            str(executable),
                            str(Path(__file__).resolve()),
                            "--worker",
                            component,
                            "--image",
                            str(fixture),
                            "--config",
                            str(config_file),
                        ],
                        check=True,
                        capture_output=True,
                        text=True,
                        timeout=45,
                        creationflags=subprocess.CREATE_NO_WINDOW
                        if os.name == "nt"
                        else 0,
                    )
                    results.append(json.loads(process.stdout))
                assert results[0] == results[1], (
                    "Training/serving preprocessing diverged"
                )
                assert results[0]["array_hash"] == results[0]["tensor_hash"]
                comparisons += 1
    print(
        f"PASS: {comparisons} synthetic image/config cases have identical implementation, masks, CHW arrays, tensors and provenance in both environments."
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worker", choices=("ai-service", "ml-training"))
    parser.add_argument("--image", type=Path)
    parser.add_argument("--config", type=Path)
    args = parser.parse_args()
    if args.worker:
        if args.image is None or args.config is None:
            parser.error("Worker requires image/config")
        worker(args.worker, args.image, args.config)
    else:
        check()


if __name__ == "__main__":
    main()
