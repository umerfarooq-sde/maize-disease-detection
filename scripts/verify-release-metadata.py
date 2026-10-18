"""Offline immutable research-model metadata pins. No dataset/test rescoring."""

import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
directory = root / "ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness"
metadata = directory / "model-artifact.json"
assert (
    hashlib.sha256(metadata.read_bytes()).hexdigest()
    == "a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d"
)
data = json.loads(metadata.read_bytes())
assert (
    data["calibration"]["configuration"]["sha256"]
    == hashlib.sha256((directory / "calibration/calibration-config.json").read_bytes()).hexdigest()
)
print(
    "PASS: approved metadata and calibration-sidecar hashes. Chec"
    "kpoint loading is a separate protected-runtime check."
)
