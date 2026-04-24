from fastapi import FastAPI
import joblib
import pandas as pd
import time
import numpy as np
from pydantic import BaseModel
from typing import List
import os

app = FastAPI()
MODEL_PATH = 'models/lgb_model.joblib'

# Delay loading to allow benchmark to finish in user_data
model = None
if os.path.exists(MODEL_PATH):
    model = joblib.load(MODEL_PATH)

class PredictionOutput(BaseModel):
    prediction: float
    latency_ms: float

@app.get("/health")
def health():
    return {"status": "ok" if model else "model_not_loaded"}

@app.post("/predict", response_model=PredictionOutput)
def predict(data: dict):
    if not model:
        return {"prediction": 0.0, "latency_ms": 0.0}
    start = time.time()
    df = pd.DataFrame([data])
    pred = model.predict(df)[0]
    return {"prediction": float(pred), "latency_ms": (time.time() - start) * 1000}

@app.post("/predict-batch")
def predict_batch(count: int = 1000):
    if not model:
        return {"status": "model_not_ready"}
    # Load some data for testing
    if not os.path.exists('creditcard.csv'):
        return {"status": "data_not_found"}
    df_test = pd.read_csv('creditcard.csv', nrows=count).drop('Class', axis=1)
    start = time.time()
    preds = model.predict(df_test)
    latency = (time.time() - start) * 1000
    return {"count": count, "latency_ms": latency, "avg_per_row_ms": latency/count}
