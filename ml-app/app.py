from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import numpy as np
import time
import os
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(title="Iris ML API")

# Setup Prometheus monitoring
Instrumentator().instrument(app).expose(app)

# Load model
MODEL_PATH = "models/model.joblib"
if os.path.exists(MODEL_PATH):
    model = joblib.load(MODEL_PATH)
else:
    model = None
    print(f"Warning: Model not found at {MODEL_PATH}")

class IrisInput(BaseModel):
    sepal_length: float
    sepal_width: float
    petal_length: float
    petal_width: float

class PredictionOutput(BaseModel):
    prediction: int
    class_name: str
    latency_ms: float

class_names = ['setosa', 'versicolor', 'virginica']

@app.get("/health")
async def health():
    if model is None:
        return {"status": "unhealthy", "reason": "model_not_loaded"}
    return {"status": "healthy"}

@app.post("/predict", response_model=PredictionOutput)
async def predict(data: IrisInput):
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    start_time = time.time()
    
    features = np.array([[
        data.sepal_length, 
        data.sepal_width, 
        data.petal_length, 
        data.petal_width
    ]])
    
    prediction = int(model.predict(features)[0])
    
    latency = (time.time() - start_time) * 1000
    
    return {
        "prediction": prediction,
        "class_name": class_names[prediction],
        "latency_ms": latency
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
