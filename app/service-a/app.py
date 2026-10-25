import socket
from flask import Flask

app = Flask(__name__)


@app.route("/api/sa")
def hello():
    return f"Hello from Service A! (pod: {socket.gethostname()})\n"


@app.route("/health")
def health():
    return "ok\n"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)