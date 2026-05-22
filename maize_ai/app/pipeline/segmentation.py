import cv2
import numpy as np

def segment_leaf(image):

    hsv = cv2.cvtColor(image, cv2.COLOR_RGB2HSV)

    lower = np.array([25, 40, 40])
    upper = np.array([95, 255, 255])

    mask = cv2.inRange(hsv, lower, upper)

    segmented = cv2.bitwise_and(image, image, mask=mask)

    return segmented