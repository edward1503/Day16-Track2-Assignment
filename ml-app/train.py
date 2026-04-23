import time
import numpy as np
import joblib
import json
import psutil
import os
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score

def get_system_metrics():
    cpu_usage = psutil.cpu_percent(interval=1)
    memory_usage = psutil.virtual_memory().percent
    return cpu_usage, memory_usage

def main():
    print("Starting ML Training Job...")
    start_time = time.time()
    
    # Initial system state
    start_cpu, start_mem = get_system_metrics()

    # Load data
    print("Loading Iris dataset...")
    data = load_iris()
    X, y = data.data, data.target

    # Split data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Train model
    print("Training Random Forest model...")
    model = RandomForestClassifier(n_estimators=100)
    model.fit(X_train, y_train)

    # Predict
    print("Evaluating model...")
    y_pred = model.predict(X_test)
    
    # Model Quality Metrics
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred, average='weighted')
    recall = recall_score(y_test, y_pred, average='weighted')
    f1 = f1_score(y_test, y_pred, average='weighted')

    # Final system state
    end_cpu, end_mem = get_system_metrics()
    end_time = time.time()
    latency = end_time - start_time

    metrics = {
        "accuracy": float(accuracy),
        "precision": float(precision),
        "recall": float(recall),
        "f1_score": float(f1),
        "training_latency_sec": float(latency),
        "avg_cpu_usage_percent": float((start_cpu + end_cpu) / 2),
        "avg_memory_usage_percent": float((start_mem + end_mem) / 2),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }

    print("-" * 30)
    print(f"Training Results:")
    print(json.dumps(metrics, indent=4))
    print("-" * 30)

    # Save artifacts
    os.makedirs("models", exist_ok=True)
    joblib.dump(model, "models/model.joblib")
    with open("models/metrics.json", "w") as f:
        json.dump(metrics, f, indent=4)
    
    print("Job Completed successfully! Model and metrics saved in models/")

if __name__ == "__main__":
    main()
