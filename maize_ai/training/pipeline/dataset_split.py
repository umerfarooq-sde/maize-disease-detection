import os
import shutil
import random

RAW_DIR = r"E:\FYP\maize_ai\training\dataset\raw\data"
OUT_DIR = r"E:\FYP\maize_ai\training\dataset"

CLASSES = ["Blight", "Common_Rust", "Gray_Leaf_Spot", "Healthy"]

TRAIN_RATIO = 0.7
VAL_RATIO = 0.15


def create_dirs():
    for split in ["train", "val", "test"]:
        for cls in CLASSES:
            os.makedirs(os.path.join(OUT_DIR, split, cls), exist_ok=True)


def split_dataset():
    create_dirs()

    for cls in CLASSES:

        class_path = os.path.join(RAW_DIR, cls)

        images = [
            f for f in os.listdir(class_path)
            if f.lower().endswith(('.jpg', '.jpeg', '.png'))
        ]

        print(cls, "->", len(images), "images found")

        random.shuffle(images)

        total = len(images)

        train_end = int(total * TRAIN_RATIO)
        val_end = int(total * (TRAIN_RATIO + VAL_RATIO))

        train = images[:train_end]
        val = images[train_end:val_end]
        test = images[val_end:]

        for img in train:
            shutil.copy(
                os.path.join(class_path, img),
                os.path.join(OUT_DIR, "train", cls, img)
            )

        for img in val:
            shutil.copy(
                os.path.join(class_path, img),
                os.path.join(OUT_DIR, "val", cls, img)
            )

        for img in test:
            shutil.copy(
                os.path.join(class_path, img),
                os.path.join(OUT_DIR, "test", cls, img)
            )

    print("Dataset splitting completed!")


if __name__ == "__main__":
    split_dataset()