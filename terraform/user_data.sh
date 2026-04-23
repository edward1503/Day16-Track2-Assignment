#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data setup for Simplified ML App"

# 1. Install Docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# 2. Create ML App Directory
mkdir -p /home/ubuntu/ml-app
cd /home/ubuntu/ml-app

# 3. Create Application Files
cat <<'EOF' > train.py
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
    start_time = time.time()
    start_cpu, start_mem = get_system_metrics()
    data = load_iris()
    X, y = data.data, data.target
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    model = RandomForestClassifier(n_estimators=100)
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred, average='weighted')
    recall = recall_score(y_test, y_pred, average='weighted')
    f1 = f1_score(y_test, y_pred, average='weighted')
    end_cpu, end_mem = get_system_metrics()
    end_time = time.time()
    metrics = {
        "accuracy": float(accuracy),
        "precision": float(precision),
        "recall": float(recall),
        "f1_score": float(f1),
        "training_latency_sec": float(end_time - start_time),
        "avg_cpu_usage_percent": float((start_cpu + end_cpu) / 2),
        "avg_memory_usage_percent": float((start_mem + end_mem) / 2),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    os.makedirs("models", exist_ok=True)
    joblib.dump(model, "models/model.joblib")
    with open("models/metrics.json", "w") as f:
        json.dump(metrics, f, indent=4)
    print("Training completed.")

if __name__ == "__main__":
    main()
EOF

cat <<'EOF' > app.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import numpy as np
import time
import os
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(title="Iris ML API")
Instrumentator().instrument(app).expose(app)
MODEL_PATH = "models/model.joblib"
model = joblib.load(MODEL_PATH) if os.path.exists(MODEL_PATH) else None

class IrisInput(BaseModel):
    sepal_length: float
    sepal_width: float
    petal_length: float
    petal_width: float

class_names = ['setosa', 'versicolor', 'virginica']

@app.get("/health")
async def health():
    return {"status": "healthy" if model else "unhealthy"}

@app.post("/predict")
async def predict(data: IrisInput):
    if not model: raise HTTPException(status_code=503, detail="Model not loaded")
    start_time = time.time()
    features = np.array([[data.sepal_length, data.sepal_width, data.petal_length, data.petal_width]])
    prediction = int(model.predict(features)[0])
    return {"prediction": prediction, "class_name": class_names[prediction], "latency_ms": (time.time() - start_time) * 1000}
EOF

cat <<'EOF' > ui.py
import streamlit as st
import requests
import json
import os
import pandas as pd
import time
st.set_page_config(page_title="Iris ML Dashboard", layout="wide")
st.title("🌸 Iris Species Predictor & Monitoring")
METRICS_PATH = "models/metrics.json"
if os.path.exists(METRICS_PATH):
    with open(METRICS_PATH, "r") as f:
        metrics = json.load(f)
    st.sidebar.header("📊 Training Summary")
    st.sidebar.metric("Accuracy", f"{metrics['accuracy']:.4f}")
    st.sidebar.metric("F1 Score", f"{metrics['f1_score']:.4f}")
    st.sidebar.subheader("System Usage")
    st.sidebar.write(f"CPU: {metrics['avg_cpu_usage_percent']}%")
    st.sidebar.write(f"RAM: {metrics['avg_memory_usage_percent']}%")
col1, col2 = st.columns([1, 1])
with col1:
    st.subheader("🔍 Make a Prediction")
    sl = st.slider("Sepal Length", 4.0, 8.0, 5.1)
    sw = st.slider("Sepal Width", 2.0, 4.5, 3.5)
    pl = st.slider("Petal Length", 1.0, 7.0, 1.4)
    pw = st.slider("Petal Width", 0.1, 2.5, 0.2)
    if st.button("Predict"):
        try:
            res = requests.post("http://localhost:8000/predict", json={"sepal_length": sl, "sepal_width": sw, "petal_length": pl, "petal_width": pw})
            if res.status_code == 200:
                result = res.json()
                st.success(f"**Predicted Class:** {result['class_name'].upper()}")
                if 'history' not in st.session_state: st.session_state.history = []
                st.session_state.history.append({"latency": result['latency_ms'], "timestamp": time.time()})
        except Exception as e: st.error(f"Error: {e}")
with col2:
    st.subheader("📈 Real-time Monitoring")
    if 'history' in st.session_state and len(st.session_state.history) > 0:
        df = pd.DataFrame(st.session_state.history)
        st.metric("Current Latency", f"{df['latency'].iloc[-1]:.2f} ms")
        st.line_chart(df['latency'].tail(20))
EOF

cat <<'EOF' > requirements.txt
fastapi
uvicorn
streamlit
joblib
scikit-learn
pandas
psutil
prometheus-fastapi-instrumentator
requests
EOF

cat <<'EOF' > entrypoint.sh
#!/bin/bash
python train.py
uvicorn app:app --host 0.0.0.0 --port 8000 &
streamlit run ui.py --server.port 8501 --server.address 0.0.0.0
wait
EOF
chmod +x entrypoint.sh

cat <<'EOF' > Dockerfile
FROM python:3.9-slim
WORKDIR /app
RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN chmod +x entrypoint.sh
EXPOSE 8000 8501
CMD ["./entrypoint.sh"]
EOF

# 4. Build and run the container with auto-restart
docker build -t ml-app .
docker run -d --name ml-app-container --restart always -p 8000:8000 -p 8501:8501 ml-app

echo "Setup complete. App is running."