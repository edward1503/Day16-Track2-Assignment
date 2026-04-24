import pandas as pd
import numpy as np
import lightgbm as lgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
import time
import json
import joblib
import os

def run_benchmark():
    print("Loading dataset (limited to 50k rows for light deployment)...")
    start_load = time.time()
    if not os.path.exists('creditcard.csv'):
        print("Error: creditcard.csv not found. Please run kaggle download first.")
        return
    
    df = pd.read_csv('creditcard.csv', nrows=50000)
    load_time = time.time() - start_load
    
    X = df.drop('Class', axis=1)
    y = df['Class']
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print("Training LightGBM model...")
    train_data = lgb.Dataset(X_train, label=y_train)
    params = {
        'objective': 'binary',
        'metric': 'auc',
        'verbose': -1,
        'boosting_type': 'gbdt',
        'num_leaves': 31,
        'learning_rate': 0.05,
        'feature_fraction': 0.9
    }
    
    start_train = time.time()
    model = lgb.train(params, train_data, num_boost_round=100)
    train_time = time.time() - start_train
    
    print("Evaluating model...")
    y_pred_prob = model.predict(X_test)
    y_pred = (y_pred_prob > 0.5).astype(int)
    
    metrics = {
        "load_time_sec": load_time,
        "training_time_sec": train_time,
        "accuracy": accuracy_score(y_test, y_pred),
        "precision": precision_score(y_test, y_pred),
        "recall": recall_score(y_test, y_pred),
        "f1_score": f1_score(y_test, y_pred),
        "auc_roc": roc_auc_score(y_test, y_pred_prob),
        "best_iteration": model.best_iteration
    }
    
    # Inference Latency (1 row)
    sample_row = X_test.iloc[0:1]
    latencies = []
    for _ in range(100):
        s = time.time()
        model.predict(sample_row)
        latencies.append(time.time() - s)
    metrics["inference_latency_1row_ms"] = np.mean(latencies) * 1000
    
    # Inference Throughput (1000 rows)
    sample_batch = X_test.iloc[0:1000]
    s = time.time()
    model.predict(sample_batch)
    metrics["inference_latency_1000rows_ms"] = (time.time() - s) * 1000
    
    print("\n--- BENCHMARK RESULTS ---")
    for k, v in metrics.items():
        print(f"{k}: {v:.4f}")
    
    # Save model and metrics
    os.makedirs('models', exist_ok=True)
    joblib.dump(model, 'models/lgb_model.joblib')
    with open('benchmark_result.json', 'w') as f:
        json.dump(metrics, f, indent=4)

if __name__ == "__main__":
    run_benchmark()
