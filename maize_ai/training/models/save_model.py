import torch

def save_model(model, path):
    torch.save(model, path)
    print(f"Model saved at {path}")