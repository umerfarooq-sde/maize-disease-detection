import torch
import numpy as np
from app.core.config import MODEL_PATH, CLASSES, CONFIDENCE_THRESHOLD

# Load model once at startup
model = torch.load(MODEL_PATH, map_location="cpu", weights_only=False)
model.eval()


def predict_model(tensor):

    x = torch.tensor(tensor, dtype=torch.float32)

    with torch.no_grad():
        output = model(x)
        probs = torch.softmax(output, dim=1)

        conf, pred = torch.max(probs, 1)

    confidence = float(conf.item())
    label = CLASSES[pred.item()]

    # confidence filtering
    if confidence < CONFIDENCE_THRESHOLD:
        return {
            "prediction": "Uncertain",
            "confidence": confidence
        }

    return {
        "prediction": label,
        "confidence": confidence
    }