#!/bin/bash

echo "--- 🛠 Step 1: Training the model ---"
python train.py

echo "--- 🚀 Step 2: Starting FastAPI (Backend) ---"
uvicorn app:app --host 0.0.0.0 --port 8000 &

echo "--- 🎨 Step 3: Starting Streamlit (Frontend) ---"
streamlit run ui.py --server.port 8501 --server.address 0.0.0.0

# Wait for background processes
wait
