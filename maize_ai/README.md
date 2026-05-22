# maize_ai

A lightweight FastAPI service scaffold for maize analysis.

## Structure

- `app/main.py` - FastAPI entry point
- `app/api/routes.py` - API endpoints
- `app/core/config.py` - application settings
- `app/core/model_loader.py` - model loading helper
- `app/pipeline/` - preprocessing, quality check, segmentation, postprocessing
- `app/utils/` - image utilities and transforms
- `app/models/maize_model.pt` - placeholder model file

## Install

```bash
pip install -r requirements.txt
```

## Run

```bash
uvicorn app.main:app --reload
```
