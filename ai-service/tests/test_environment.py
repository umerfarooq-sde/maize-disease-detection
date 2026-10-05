"""Dependency smoke checks, not production endpoints or preprocessing."""

import asyncio
import sys

import cv2
import httpx
import numpy as np
import torch
import torchvision
import uvicorn
from fastapi import FastAPI
from PIL import Image


def test_isolated_python_environment():
    assert sys.version_info[:2] == (3, 11)
    assert sys.prefix != sys.base_prefix
    assert uvicorn.__version__
    assert httpx.__version__


def test_fastapi_asgi_request():
    app = FastAPI()

    @app.get("/dependency-probe")
    def dependency_probe():
        return {"available": True}

    async def request_probe():
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://testserver"
        ) as client:
            return await client.get("/dependency-probe")

    response = asyncio.run(request_probe())
    assert response.status_code == 200
    assert response.json() == {"available": True}


def test_image_and_cpu_tensor_dependencies():
    pixels = np.zeros((8, 8, 3), dtype=np.uint8)
    assert Image.fromarray(pixels).size == (8, 8)
    encoded, buffer = cv2.imencode(".png", pixels)
    assert encoded
    assert cv2.imdecode(buffer, cv2.IMREAD_COLOR).shape == pixels.shape
    assert torch.ones(2, 3).sum().item() == 6
    # Exercise compiled torchvision CPU operators, catching mismatched wheels.
    boxes = torch.tensor([[0.0, 0.0, 2.0, 2.0], [0.0, 0.0, 2.0, 2.0]])
    assert torchvision.ops.nms(boxes, torch.tensor([0.9, 0.8]), 0.5).tolist() == [0]
