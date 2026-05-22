import cv2
import numpy as np

IMAGE_SIZE = (224, 224)


def resize(image):
    return cv2.resize(image, IMAGE_SIZE)


def normalize(image):
    return image.astype(np.float32) / 255.0


def preprocess(image):
    image = resize(image)
    image = normalize(image)
    return image