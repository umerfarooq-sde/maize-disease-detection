import cv2

from app.pipeline.quality_check import check_image_quality
from app.pipeline.segmentation import segment_leaf

from app.utils.image_utils import resize, denoise
from app.utils.transforms import normalize, to_tensor


# -------------------------
# CLAHE + LAB enhancement
# -------------------------
def clahe(image):

    lab = cv2.cvtColor(image, cv2.COLOR_RGB2LAB)
    l, a, b = cv2.split(lab)

    c = cv2.createCLAHE(2.0, (8, 8))
    l = c.apply(l)

    lab = cv2.merge((l, a, b))
    return cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)


# -------------------------
# FULL PIPELINE
# -------------------------
def process_image(image):

    # 1. Quality check
    ok, msg = check_image_quality(image)
    if not ok:
        return {"error": msg}

    # 2. Resize
    image = resize(image)

    # 3. Denoise
    image = denoise(image)

    # 4. CLAHE enhancement
    image = clahe(image)

    # 5. Segmentation
    image = segment_leaf(image)

    # 6. Normalize
    image = normalize(image)

    # 7. Tensor conversion
    tensor = to_tensor(image)

    return tensor