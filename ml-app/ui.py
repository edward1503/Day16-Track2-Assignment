import streamlit as st
import requests
import json
import os
import pandas as pd
import time

st.set_page_config(page_title="Iris ML Dashboard", layout="wide")

st.title("🌸 Iris Species Predictor & Monitoring")

# --- Sidebar: Training Metrics ---
st.sidebar.header("📊 Training Summary")
METRICS_PATH = "models/metrics.json"

if os.path.exists(METRICS_PATH):
    with open(METRICS_PATH, "r") as f:
        metrics = json.load(f)
    
    st.sidebar.metric("Accuracy", f"{metrics['accuracy']:.4f}")
    st.sidebar.metric("F1 Score", f"{metrics['f1_score']:.4f}")
    st.sidebar.metric("Training Latency", f"{metrics['training_latency_sec']:.4f}s")
    
    st.sidebar.markdown("---")
    st.sidebar.subheader("System Usage (Training)")
    st.sidebar.write(f"CPU: {metrics['avg_cpu_usage_percent']}%")
    st.sidebar.write(f"RAM: {metrics['avg_memory_usage_percent']}%")
else:
    st.sidebar.warning("No training metrics found. Please run training first.")

# --- Main Section: Prediction ---
col1, col2 = st.columns([1, 1])

with col1:
    st.subheader("🔍 Make a Prediction")
    sl = st.slider("Sepal Length", 4.0, 8.0, 5.1)
    sw = st.slider("Sepal Width", 2.0, 4.5, 3.5)
    pl = st.slider("Petal Length", 1.0, 7.0, 1.4)
    pw = st.slider("Petal Width", 0.1, 2.5, 0.2)
    
    if st.button("Predict"):
        payload = {
            "sepal_length": sl,
            "sepal_width": sw,
            "petal_length": pl,
            "petal_width": pw
        }
        
        try:
            # Call FastAPI (assuming it's on localhost:8000 for local or same host)
            # In production, this might be a relative path or fixed IP
            res = requests.post("http://localhost:8000/predict", json=payload)
            if res.status_code == 200:
                result = res.json()
                st.success(f"**Predicted Class:** {result['class_name'].upper()}")
                
                # Update Session State for real-time metrics
                if 'history' not in st.session_state:
                    st.session_state.history = []
                st.session_state.history.append({
                    "latency": result['latency_ms'],
                    "timestamp": time.time()
                })
            else:
                st.error("Error from API")
        except Exception as e:
            st.error(f"Connection failed: {e}")

with col2:
    st.subheader("📈 Real-time Monitoring")
    if 'history' in st.session_state and len(st.session_state.history) > 0:
        df = pd.DataFrame(st.session_state.history)
        
        # Latency Metric
        latest_latency = df['latency'].iloc[-1]
        avg_latency = df['latency'].mean()
        
        m1, m2 = st.columns(2)
        m1.metric("Current Latency", f"{latest_latency:.2f} ms")
        m2.metric("Avg Latency", f"{avg_latency:.2f} ms")
        
        # Throughput (approximate)
        st.write("**Recent Requests (Latency ms)**")
        st.line_chart(df['latency'].tail(20))
    else:
        st.info("Make some predictions to see real-time metrics.")

# --- Bottom Section: Raw Metrics ---
with st.expander("View Full Training Metrics"):
    if os.path.exists(METRICS_PATH):
        st.json(metrics)
    else:
        st.write("No metrics available.")
