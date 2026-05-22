import numpy as np

def normalize(image):
    return image.astype(np.float32) / 255.0


def to_tensor(image):
    image = np.transpose(image, (2, 0, 1))
    return np.expand_dims(image, axis=0)