"""
Minimal microservice used to demonstrate the GitOps + DevSecOps pipeline.
Swap this out for any real service — the pipeline around it is the point.
"""
from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "dev")


@app.get("/")
def index():
    return jsonify(
        message="hello from the devsecops demo service",
        version=APP_VERSION,
        hostname=socket.gethostname(),
    )


@app.get("/healthz")
def healthz():
    # Liveness probe target — keep this cheap and dependency-free.
    return jsonify(status="ok"), 200


@app.get("/readyz")
def readyz():
    # Readiness probe target — in a real service, check DB/cache connectivity here.
    return jsonify(status="ready"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
