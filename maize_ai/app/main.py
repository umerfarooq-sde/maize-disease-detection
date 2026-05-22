from fastapi import FastAPI
from app.api.routes import router

app = FastAPI(
    title="Maize AI Disease Detection",
    description="ML API for maize leaf disease detection"
)

app.include_router(router)

@app.get("/")
def home():
    return {
        "message": "Maize AI Service Running"
    }