#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data setup for ML CPU Benchmark (LightGBM)"

# 1. Update and Install System Dependencies
dnf update -y
dnf install -y python3 python3-pip git

# 2. Set up Kaggle CLI and Credentials
pip3 install --upgrade pip
pip3 install kaggle

mkdir -p /home/ec2-user/.kaggle
cat <<EOF > /home/ec2-user/.kaggle/kaggle.json
{"username": "${kaggle_username}", "key": "${kaggle_key}"}
EOF
chmod 600 /home/ec2-user/.kaggle/kaggle.json
chown ec2-user:ec2-user /home/ec2-user/.kaggle/kaggle.json

# 3. Create Project Directory
mkdir -p /home/ec2-user/ml-project/models
cd /home/ec2-user/ml-project

# 4. Download Dataset
sudo -u ec2-user kaggle datasets download -d mlg-ulb/creditcardfraud --unzip -p /home/ec2-user/ml-project/

# 5. Create benchmark.py
cat <<'EOF' > benchmark.py
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
    print("Loading dataset (limited to 50k rows)...")
    start_load = time.time()
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
    joblib.dump(model, 'models/lgb_model.joblib')
    with open('benchmark_result.json', 'w') as f:
        json.dump(metrics, f, indent=4)

if __name__ == "__main__":
    run_benchmark()
EOF

# 6. Create app.py (FastAPI)
cat <<'EOF' > app.py
from fastapi import FastAPI
import joblib
import pandas as pd
import time
import numpy as np
from pydantic import BaseModel
from typing import List

app = FastAPI()
model = joblib.load('models/lgb_model.joblib')

class PredictionOutput(BaseModel):
    prediction: float
    latency_ms: float

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/predict", response_model=PredictionOutput)
def predict(data: dict):
    start = time.time()
    df = pd.DataFrame([data])
    pred = model.predict(df)[0]
    return {"prediction": float(pred), "latency_ms": (time.time() - start) * 1000}

@app.post("/predict-batch")
def predict_batch(count: int = 1000):
    # Load some data for testing
    df_test = pd.read_csv('creditcard.csv', nrows=count).drop('Class', axis=1)
    start = time.time()
    preds = model.predict(df_test)
    latency = (time.time() - start) * 1000
    return {"count": count, "latency_ms": latency, "avg_per_row_ms": latency/count}
EOF

# 7. Create ui.py (Streamlit)
cat <<'EOF' > ui.py
import streamlit as st
import pandas as pd
import requests
import time
import plotly.express as px
import json
import os

st.set_page_config(page_title="ML CPU Benchmark Dashboard", layout="wide")
st.title("🚀 ML CPU Performance Dashboard (r5.2xlarge)")

# Sidebar: Display Benchmark Results
if os.path.exists('benchmark_result.json'):
    with open('benchmark_result.json', 'r') as f:
        metrics = json.load(f)
    st.sidebar.header("📊 Offline Benchmark Results")
    st.sidebar.metric("AUC-ROC", f"{metrics['auc_roc']:.4f}")
    st.sidebar.metric("Training Time", f"{metrics['training_time_sec']:.2f}s")
    st.sidebar.metric("F1-Score", f"{metrics['f1_score']:.4f}")

col1, col2 = st.columns(2)

with col1:
    st.subheader("⚡ Real-time Inference Test")
    if st.button("Run 1 Request (Single Row)"):
        # Dummy row for testing
        data = {f"V{i}": 0.0 for i in range(1, 29)}
        data["Time"] = 0
        data["Amount"] = 100.0
        
        res = requests.post("http://localhost:8000/predict", json=data).json()
        st.success(f"Latency: {res['latency_ms']:.4f} ms")
        st.write(f"Prediction (Fraud Prob): {res['prediction']:.4f}")

    if st.button("Run 1000 Requests (Batch)"):
        res = requests.post("http://localhost:8000/predict-batch?count=1000").json()
        st.info(f"Total Latency for 1000 rows: {res['latency_ms']:.2f} ms")
        st.info(f"Average Latency per row: {res['avg_per_row_ms']:.4f} ms")
        
        # Visualize
        df_viz = pd.DataFrame({
            "Type": ["Total Batch", "Avg per Row"],
            "ms": [res['latency_ms'], res['avg_per_row_ms']]
        })
        fig = px.bar(df_viz, x="Type", y="ms", title="Latency Comparison")
        st.plotly_chart(fig)

with col2:
    st.subheader("📈 Latency History")
    if 'history' not in st.session_state:
        st.session_state.history = []
    
    if st.button("Generate Latency Chart (100 samples)"):
        data = {f"V{i}": 0.0 for i in range(1, 29)}
        data["Time"] = 0
        data["Amount"] = 100.0
        
        new_history = []
        for _ in range(100):
            res = requests.post("http://localhost:8000/predict", json=data).json()
            new_history.append(res['latency_ms'])
        
        st.session_state.history = new_history
        st.line_chart(st.session_state.history)
        st.write(f"Mean Latency: {sum(new_history)/len(new_history):.4f} ms")

EOF

# 8. Install Python Libraries
pip3 install lightgbm scikit-learn pandas numpy fastapi uvicorn streamlit plotly joblib requests

# 9. Run Benchmark and Start Services
chown -R ec2-user:ec2-user /home/ec2-user/ml-project
sudo -u ec2-user python3 benchmark.py

# Start FastAPI and Streamlit
sudo -u ec2-user nohup uvicorn app:app --host 0.0.0.0 --port 8000 > fastapi.log 2>&1 &
sudo -u ec2-user nohup streamlit run ui.py --server.port 8501 --server.address 0.0.0.0 > streamlit.log 2>&1 &

echo "Setup complete."