import cv2
import numpy as np

def check_image_quality(image):

    gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)

    blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()
    brightness = np.mean(gray)

    if blur_score < 50:
        return False, "Image too blurry"
    if brightness < 40:
        return False, "Image too dark"

    return True, "OK"