from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify(service="servicelink-widget-api", status="ok")

@app.route("/health")
def health():
    return jsonify(status="healthy"), 200

def add(a, b):
    """Trivial business logic used to demonstrate a unit test."""
    return a + b

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
