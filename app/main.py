import random
import time

from flask import Flask, jsonify, Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

REQUEST_COUNT = Counter(
    "quote_api_requests_total",
    "Total number of API requests",
    ["endpoint"]
)

QUOTES = [
    "Great things are done by a series of small things brought together.",
    "Success is the sum of small efforts repeated day in and day out.",
    "The secret of getting ahead is getting started.",
    "It always seems impossible until it's done.",
    "Quality is not an act, it is a habit."
]


@app.route("/healthz")
def healthz():
    REQUEST_COUNT.labels(endpoint="/healthz").inc()
    return jsonify(status="healthy"), 200


@app.route("/readyz")
def readyz():
    REQUEST_COUNT.labels(endpoint="/readyz").inc()
    return jsonify(status="ready"), 200


@app.route("/metrics")
def metrics():
    return Response(
        generate_latest(),
        mimetype=CONTENT_TYPE_LATEST
    )


@app.route("/api/quote")
def quote():
    REQUEST_COUNT.labels(endpoint="/api/quote").inc()

    # Simulate approximately 100ms of CPU work
    start = time.perf_counter()
    while time.perf_counter() - start < 0.1:
        pass

    return jsonify(
        quote=random.choice(QUOTES),
        timestamp=time.time()
    )


