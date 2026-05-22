MODEL_PATH = "app/models/best_mobilenetv2_maize.pt"

IMAGE_SIZE = (224, 224)

NUM_CLASSES = 4

CLASSES = [
    "Blight",
    "Common_Rust",
    "Gray_Leaf_Spot",
    "Healthy"
]

TRAIN_SPLIT = 0.7
VAL_SPLIT = 0.15
TEST_SPLIT = 0.15

BATCH_SIZE = 32
EPOCHS = 10
LEARNING_RATE = 0.0001

CONFIDENCE_THRESHOLD = 0.6