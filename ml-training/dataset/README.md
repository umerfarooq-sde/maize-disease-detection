# ML workspace areas

This README describes optional local dataset and model-development workspace areas.
The local subdirectories are empty and are not tracked by Git. No project dataset,
executable pipeline, experiment output, or trained model is included here.

- `preprocessing/`: preprocessing ownership and training/inference parity.
- `training/`: training pipeline constraints.
- `evaluation/`: validation and held-out evaluation requirements.
- `experiments/`: reproducibility and experiment metadata.
- `models/`: model versioning and artifact handling.

Keep private or licensed image datasets and generated model binaries out of Git.
Repository ignore rules cover local raw/processed/split data and common model formats.
The implemented pipeline remains in `../train.py`, `../training_data.py` and
`../evaluation.py`; `../preprocessing.py` uses the shared preprocessing package.
These workspace names do not introduce another training or preprocessing implementation.
