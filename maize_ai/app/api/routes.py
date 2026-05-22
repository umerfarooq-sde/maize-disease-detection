from fastapi import APIRouter, File, UploadFile
import numpy as np
import cv2

from app.pipeline.preprocess import process_image
from app.core.model_loader import predict_model

router = APIRouter()


@router.post("/predict")
async def predict(file: UploadFile = File(...)):

    # Read image
    image_bytes = await file.read()
    np_arr = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    # Pipeline
    tensor = process_image(image)

    # Error handling from pipeline
    if isinstance(tensor, dict) and "error" in tensor:
        return tensor

    # Prediction
    result = predict_model(tensor)

    return result