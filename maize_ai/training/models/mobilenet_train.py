import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import models

from training.pipeline.dataset_loader import get_dataloaders
from training.utils.class_mapping import CLASSES


# -----------------------
# VALIDATION FUNCTION
# -----------------------
def validate(model, val_loader, criterion, device):
    model.eval()

    total_loss = 0
    correct = 0
    total = 0

    with torch.no_grad():
        for images, labels in val_loader:
            images, labels = images.to(device), labels.to(device)

            outputs = model(images)
            loss = criterion(outputs, labels)

            total_loss += loss.item()

            _, preds = torch.max(outputs, 1)
            correct += (preds == labels).sum().item()
            total += labels.size(0)

    acc = 100 * correct / total
    return total_loss, acc


# -----------------------
# LOAD DATA
# -----------------------
train_loader, val_loader, test_loader = get_dataloaders()


# -----------------------
# DEVICE
# -----------------------
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# -----------------------
# MODEL (MobileNetV2)
# -----------------------
model = models.mobilenet_v2(pretrained=True)

# Freeze base model first (IMPORTANT FOR STABILITY)
for param in model.features.parameters():
    param.requires_grad = False

# Replace classifier
model.classifier[1] = nn.Linear(model.last_channel, len(CLASSES))

model = model.to(device)


# -----------------------
# LOSS (with class weights - IMPORTANT)
# -----------------------
class_weights = torch.tensor([1.0, 1.0, 2.0, 1.0]).to(device)
criterion = nn.CrossEntropyLoss(weight=class_weights)


# -----------------------
# OPTIMIZER (LOW LR FOR FINE TUNING)
# -----------------------
optimizer = optim.Adam(model.parameters(), lr=1e-4)

# Optional: LR scheduler (VERY USEFUL)
scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=3, gamma=0.5)


# -----------------------
# TRAINING LOOP
# -----------------------
EPOCHS = 10
best_acc = 0


for epoch in range(EPOCHS):

    # -----------------------
    # TRAIN PHASE
    # -----------------------
    model.train()
    total_loss = 0

    for images, labels in train_loader:

        images, labels = images.to(device), labels.to(device)

        outputs = model(images)
        loss = criterion(outputs, labels)

        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        total_loss += loss.item()

    # -----------------------
    # UNFREEZE LATER (FINE TUNING STEP)
    # -----------------------
    if epoch == 3:
        print("🔓 Unfreezing last layers for fine-tuning...")

        for param in model.features[-2:].parameters():
            param.requires_grad = True


    # -----------------------
    # VALIDATION PHASE
    # -----------------------
    val_loss, val_acc = validate(model, val_loader, criterion, device)

    scheduler.step()

    print(f"""
Epoch {epoch+1}/{EPOCHS}
Train Loss: {total_loss:.4f}
Val Loss: {val_loss:.4f}
Val Accuracy: {val_acc:.2f}%
""")

    # -----------------------
    # SAVE BEST MODEL
    # -----------------------
    if val_acc > best_acc:
        best_acc = val_acc

        torch.save(model, "app/models/best_mobilenetv2_maize.pt")

        print("💾 Best model saved!")

print("🎉 Training completed successfully!")