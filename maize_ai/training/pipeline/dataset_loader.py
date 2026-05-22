import torch
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
from app.core.config import IMAGE_SIZE, BATCH_SIZE


# -----------------------
# TRAIN TRANSFORM (AUGMENTATION)
# -----------------------
train_transform = transforms.Compose([
    transforms.Resize((256, 256)),

    transforms.RandomResizedCrop(IMAGE_SIZE),
    transforms.RandomHorizontalFlip(p=0.5),
    transforms.RandomRotation(25),

    transforms.ColorJitter(
        brightness=0.2,
        contrast=0.2,
        saturation=0.2,
        hue=0.1
    ),

    transforms.ToTensor(),

    transforms.Normalize(
        [0.485, 0.456, 0.406],
        [0.229, 0.224, 0.225]
    )
])


# -----------------------
# TEST / VALIDATION TRANSFORM (NO AUGMENTATION)
# -----------------------
test_transform = transforms.Compose([
    transforms.Resize(IMAGE_SIZE),

    transforms.ToTensor(),

    transforms.Normalize(
        [0.485, 0.456, 0.406],
        [0.229, 0.224, 0.225]
    )
])


# -----------------------
# DATA LOADERS
# -----------------------
def get_dataloaders():

    train_data = datasets.ImageFolder(
        r"E:\FYP\maize_ai\training\dataset\train",
        transform=train_transform
    )

    val_data = datasets.ImageFolder(
        r"E:\FYP\maize_ai\training\dataset\val",
        transform=test_transform
    )

    test_data = datasets.ImageFolder(
        r"E:\FYP\maize_ai\training\dataset\test",
        transform=test_transform
    )

    train_loader = DataLoader(
        train_data,
        batch_size=BATCH_SIZE,
        shuffle=True
    )

    val_loader = DataLoader(
        val_data,
        batch_size=BATCH_SIZE,
        shuffle=False
    )

    test_loader = DataLoader(
        test_data,
        batch_size=BATCH_SIZE,
        shuffle=False
    )

    return train_loader, val_loader, test_loader