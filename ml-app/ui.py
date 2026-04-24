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
else:
    st.sidebar.warning("Benchmark results not found yet. Please run the benchmark first.")

col1, col2 = st.columns(2)

with col1:
    st.subheader("⚡ Real-time Inference Test")
    if st.button("Run 1 Request (Single Row)"):
        # Dummy row for testing
        data = {f"V{i}": 0.0 for i in range(1, 29)}
        data["Time"] = 0
        data["Amount"] = 100.0
        
        try:
            res = requests.post("http://localhost:8000/predict", json=data).json()
            st.success(f"Latency: {res['latency_ms']:.4f} ms")
            st.write(f"Prediction (Fraud Prob): {res['prediction']:.4f}")
        except Exception as e:
            st.error(f"Error connecting to API: {e}")

    if st.button("Run 1000 Requests (Batch)"):
        try:
            res = requests.post("http://localhost:8000/predict-batch?count=1000").json()
            if 'latency_ms' in res:
                st.info(f"Total Latency for 1000 rows: {res['latency_ms']:.2f} ms")
                st.info(f"Average Latency per row: {res['avg_per_row_ms']:.4f} ms")
                
                # Visualize
                df_viz = pd.DataFrame({
                    "Type": ["Total Batch", "Avg per Row"],
                    "ms": [res['latency_ms'], res['avg_per_row_ms']]
                })
                fig = px.bar(df_viz, x="Type", y="ms", title="Latency Comparison")
                st.plotly_chart(fig)
            else:
                st.error(f"API Error: {res}")
        except Exception as e:
            st.error(f"Error connecting to API: {e}")

with col2:
    st.subheader("📈 Latency History")
    if 'history' not in st.session_state:
        st.session_state.history = []
    
    if st.button("Generate Latency Chart (100 samples)"):
        data = {f"V{i}": 0.0 for i in range(1, 29)}
        data["Time"] = 0
        data["Amount"] = 100.0
        
        try:
            new_history = []
            for _ in range(100):
                res = requests.post("http://localhost:8000/predict", json=data).json()
                new_history.append(res['latency_ms'])
            
            st.session_state.history = new_history
            st.line_chart(st.session_state.history)
            st.write(f"Mean Latency: {sum(new_history)/len(new_history):.4f} ms")
        except Exception as e:
            st.error(f"Error: {e}")
