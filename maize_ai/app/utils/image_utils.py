import cv2

def resize(image, size=(224, 224)):
    return cv2.resize(image, size)

def denoise(image):
    return cv2.bilateralFilter(image, 9, 75, 75)

def to_rgb(image):
    return cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
