import time
import numpy as np
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

def main():
    print("Starting ML Training Job...")
    start_time = time.time()

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
    accuracy = accuracy_score(y_test, y_pred)

    end_time = time.time()
    latency = end_time - start_time

    print("-" * 30)
    print(f"Training Results:")
    print(f"Accuracy: {accuracy:.4f}")
    print(f"Execution Latency: {latency:.4f} seconds")
    print("-" * 30)
    print("Job Completed successfully!")

if __name__ == "__main__":
    main()
