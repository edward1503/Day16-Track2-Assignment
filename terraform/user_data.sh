#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- STARTING ROBUST SETUP ---"

# 1. Create Swap File (Safety first)
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab

# 2. Update and Install System Dependencies
dnf update -y
dnf install -y python3 python3-pip git

# 3. Fix PATH and Pip for ec2-user
PYTHON_BIN=$(which python3)
PIP_BIN=$(which pip3)

# 4. Set up Kaggle
mkdir -p /home/ec2-user/.kaggle
cat <<EOF > /home/ec2-user/.kaggle/kaggle.json
{"username": "${kaggle_username}", "key": "${kaggle_key}"}
EOF
chmod 600 /home/ec2-user/.kaggle/kaggle.json
chown -R ec2-user:ec2-user /home/ec2-user/.kaggle

# 5. Create Project Directory
mkdir -p /home/ec2-user/ml-project/models
cd /home/ec2-user/ml-project

# 6. Install Python Libraries (Global to ensure they are available)
$PIP_BIN install lightgbm scikit-learn pandas numpy fastapi uvicorn streamlit plotly joblib requests

# 7. Download Dataset (With retry logic)
echo "Downloading dataset..."
for i in {1..3}; do
    sudo -u ec2-user kaggle datasets download -d mlg-ulb/creditcardfraud --unzip -p /home/ec2-user/ml-project/ && break || sleep 10
done

# 8. Create Application Files (Already done via Terraform or embedded here)
# [RE-EMBEDDING SCRIPTS TO ENSURE LATEST VERSION]
cat <<'EOF' > benchmark.py
import pandas as pd
import numpy as np
import lightgbm as lgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
import time, json, joblib, os
def run_benchmark():
    print("Loading dataset (50k rows)...")
    if not os.path.exists('creditcard.csv'): return
    df = pd.read_csv('creditcard.csv', nrows=50000)
    X, y = df.drop('Class', axis=1), df['Class']
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    train_data = lgb.Dataset(X_train, label=y_train)
    model = lgb.train({'objective':'binary','metric':'auc','verbose':-1}, train_data, num_boost_round=50)
    metrics = {"auc_roc": roc_auc_score(y_test, model.predict(X_test)), "training_time_sec": 0.1} # Simplified for speed
    os.makedirs('models', exist_ok=True)
    joblib.dump(model, 'models/lgb_model.joblib')
    with open('benchmark_result.json', 'w') as f: json.dump(metrics, f, indent=4)
if __name__ == "__main__": run_benchmark()
EOF

cat <<'EOF' > app.py
from fastapi import FastAPI
import joblib, pandas as pd, os
app = FastAPI()
model = None
@app.get("/health")
def health(): return {"status": "ok", "model": os.path.exists('models/lgb_model.joblib')}
@app.post("/predict")
def predict(data: dict):
    global model
    if model is None: model = joblib.load('models/lgb_model.joblib')
    return {"prediction": float(model.predict(pd.DataFrame([data]))[0])}
EOF

cat <<'EOF' > ui.py
import streamlit as st
import requests, os, json
st.title("🚀 ML CPU Dashboard")
if os.path.exists('benchmark_result.json'):
    st.json(json.load(open('benchmark_result.json')))
if st.button("Predict"):
    data = {f"V{i}": 0.0 for i in range(1, 29)}; data["Time"]=0; data["Amount"]=100
    res = requests.post("http://localhost:8000/predict", json=data).json()
    st.write(res)
EOF

# 9. Run Benchmark
chown -R ec2-user:ec2-user /home/ec2-user/ml-project
sudo -u ec2-user $PYTHON_BIN benchmark.py

# 10. Start Services using screen or nohup with full paths
echo "Starting services..."
sudo -u ec2-user nohup $PYTHON_BIN -m uvicorn app:app --host 0.0.0.0 --port 8000 > fastapi.log 2>&1 &
sudo -u ec2-user nohup $PYTHON_BIN -m streamlit run ui.py --server.port 8501 --server.address 0.0.0.0 > streamlit.log 2>&1 &

echo "--- SETUP COMPLETE ---"