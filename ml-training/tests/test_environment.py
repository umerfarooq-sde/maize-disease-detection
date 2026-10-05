"""Verify ML libraries with synthetic data only; no dataset or model training."""

import sys

import cv2
import numpy as np
import torch
import torchvision
from PIL import Image
from sklearn.metrics import confusion_matrix, f1_score


def test_isolated_python_environment():
    assert sys.version_info[:2] == (3, 11)
    assert sys.prefix != sys.base_prefix


def test_image_libraries():
    pixels = np.zeros((4, 4, 3), dtype=np.uint8)
    assert Image.fromarray(pixels).size == (4, 4)
    encoded, buffer = cv2.imencode(".png", pixels)
    assert encoded
    assert cv2.imdecode(buffer, cv2.IMREAD_COLOR).shape == pixels.shape


def test_cpu_autograd_and_torchvision():
    values = torch.tensor([1.0, 2.0], requires_grad=True)
    values.square().sum().backward()
    torch.testing.assert_close(values.grad, torch.tensor([2.0, 4.0]))
    boxes = torch.tensor([[0.0, 0.0, 2.0, 2.0]])
    assert torchvision.ops.nms(boxes, torch.tensor([0.9]), 0.5).tolist() == [0]


def test_evaluation_libraries():
    assert f1_score([0, 1, 1], [0, 1, 1], average="macro") == 1.0
    np.testing.assert_array_equal(confusion_matrix([0, 1], [0, 1]), np.eye(2, dtype=int))
