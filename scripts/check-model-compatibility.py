"""Offline checkpoint/parity/CPU diagnostics in both existing Python environments.

This is not an inference API. Only synthetic and fixed TRAIN images are inspected.
No raw images, absolute dataset path or secrets are written to the report.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[1]


def worker(component: str, experiment: Path, manifest_path: Path) -> dict[str, object]:
    import numpy as np
    import torch
    from maizedoctor_preprocessing import preprocess_file as shared_preprocess

    sys.path.insert(0, str(REPOSITORY / "ml-training"))
    from configuration import load_dataset_path
    from dataset_preparation import CLASS_LABELS, load_manifest
    from model import build_model, read_checkpoint, restore_checkpoint
    from training_data import select_smoke_rows

    if component == "ai-service":
        sys.path.insert(0, str(REPOSITORY / "ai-service"))
        from app.preprocessing import preprocess_file
    else:
        from preprocessing import preprocess_file

    assert preprocess_file is shared_preprocess
    torch.set_num_threads(2)
    torch.manual_seed(20261008)
    manifest = load_manifest(manifest_path)
    config = manifest.load_preprocessing()
    summary = json.loads((experiment / "summary.json").read_bytes())
    checkpoint = (experiment / summary["best_checkpoint"]).resolve(strict=True)
    if not checkpoint.is_relative_to(experiment.resolve(strict=True)):
        raise ValueError("Checkpoint path escapes its experiment.")
    checkpoint_hash = hashlib.sha256(checkpoint.read_bytes()).hexdigest()
    if (
        checkpoint_hash != summary["best_checkpoint_sha256"]
        or summary["manifest_fingerprint"] != manifest.fingerprint
        or summary["preprocessing_hash"] != config.fingerprint
    ):
        raise ValueError("Checkpoint or experiment/index/preprocessing pins do not agree.")
    payload = read_checkpoint(
        checkpoint,
        class_names=CLASS_LABELS,
        preprocessing_hash=manifest.preprocessing_hash,
        manifest_hash=manifest.fingerprint,
    )
    model = build_model(4, pretrained=False)
    restore_checkpoint(model, payload, 4)
    dataset = load_dataset_path()
    cases = []
    representative = None
    for row in select_smoke_rows(manifest.rows_for_split("train"), 16):
        result = preprocess_file(dataset / row.relative_path, config)
        assert result.metadata.image_hash == row.content_hash
        tensor = result.to_tensor().unsqueeze(0)
        representative = tensor
        with torch.inference_mode():
            logits = model(tensor)
        assert tuple(logits.shape) == (1, 4) and torch.isfinite(logits).all()
        cases.append(
            {
                "sample_id": row.sample_id,
                "class_index": row.class_index,
                "tensor_sha256": hashlib.sha256(tensor.numpy().tobytes()).hexdigest(),
                "logits_sha256": hashlib.sha256(logits.numpy().tobytes()).hexdigest(),
                "logits": logits[0].tolist(),
            }
        )
    assert representative is not None
    durations = []
    with torch.inference_mode():
        for _ in range(5):
            model(representative)
        for _ in range(30):
            started = time.perf_counter()
            model(representative)
            durations.append((time.perf_counter() - started) * 1000)
    memory = None
    if os.name == "nt":
        probe = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                f"Get-Process -Id {os.getpid()} | "
                "Select-Object WorkingSet64,PeakWorkingSet64 | ConvertTo-Json -Compress",
            ],
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        memory = json.loads(probe.stdout)
    parameters = list(model.parameters())
    return {
        "component": component,
        "checkpoint_sha256": checkpoint_hash,
        "manifest_fingerprint": manifest.fingerprint,
        "preprocessing_hash": config.fingerprint,
        "class_names": list(CLASS_LABELS),
        "input": {
            "shape": [1, 3, config.target_height, config.target_width],
            "dtype": "float32",
            "order": "RGB_CHW",
        },
        "output_shape": [1, 4],
        "parameter_count": sum(value.numel() for value in parameters),
        "parameter_storage_bytes": sum(
            value.numel() * value.element_size() for value in parameters
        ),
        "checkpoint_bytes": checkpoint.stat().st_size,
        "cases": cases,
        "torch_version": importlib.metadata.version("torch"),
        "torchvision_version": importlib.metadata.version("torchvision"),
        "preprocessing_package_version": importlib.metadata.version("maizedoctor-preprocessing"),
        "model_only_latency_ms": {
            "threads": 2,
            "batch_size": 1,
            "warmup": 5,
            "samples": len(durations),
            "median": statistics.median(durations),
            "p95": float(np.quantile(durations, 0.95)),
            "includes_decode_preprocessing": False,
            "limitation": (
                "Local workstation probe; concurrent audit jobs may contend for CPU. "
                "Not a serving SLA."
            ),
        },
        "process_memory_bytes": memory,
        "memory_scope": (
            "Python process after imports, checkpoint restore and batch-one inference; "
            "not measured server concurrency."
        ),
        "partitions_used": ["train"],
        "cuda_available": torch.cuda.is_available(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--experiment", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--worker", choices=("ml-training", "ai-service"))
    args = parser.parse_args()
    if args.worker:
        print(json.dumps(worker(args.worker, args.experiment, args.manifest), allow_nan=False))
        return
    if args.output is None:
        parser.error("--output is required")
    output = args.output.resolve()
    cache = (REPOSITORY / ".cache").resolve()
    if not output.is_relative_to(cache):
        parser.error("Output must be an ignored local .cache path")
    if output.exists():
        raise FileExistsError("Preserve existing diagnostic reports; choose a new output.")
    results = []
    for component in ("ml-training", "ai-service"):
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
                "--experiment",
                str(args.experiment.resolve()),
                "--manifest",
                str(args.manifest.resolve()),
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=120,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        results.append(json.loads(process.stdout))
    for key in (
        "checkpoint_sha256",
        "manifest_fingerprint",
        "preprocessing_hash",
        "class_names",
        "input",
        "output_shape",
        "parameter_count",
        "parameter_storage_bytes",
        "checkpoint_bytes",
        "cases",
        "torch_version",
        "torchvision_version",
        "preprocessing_package_version",
    ):
        if results[0][key] != results[1][key]:
            raise ValueError(f"Offline training/AI compatibility differs: {key}")
    report = {
        "passed": True,
        "case_count": len(results[0]["cases"]),
        "partitions_used": ["train"],
        "no_api_implemented": True,
        "model_outputs_exactly_equal": True,
        "environments": results,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key != "environments"}))


if __name__ == "__main__":
    main()
