import torch
from training.pipeline.dataset_loader import get_dataloaders
import app.core.config as config

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

model = torch.load(config.MODEL_PATH,weights_only=False)
model = model.to(device)

model.eval()

_, _, test_loader = get_dataloaders()

correct = 0
total = 0

with torch.no_grad():

    for images, labels in test_loader:

        images = images.to(device)
        labels = labels.to(device)

        outputs = model(images)

        _, preds = torch.max(outputs, 1)

        total += labels.size(0)
        correct += (preds == labels).sum().item()

accuracy = 100 * correct / total

print(f"Test Accuracy: {accuracy:.2f}%")