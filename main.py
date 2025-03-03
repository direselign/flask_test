from flask import Flask, render_template, jsonify

app = Flask(__name__)

# Home Page (Jinja2 Rendering)
@app.route("/")
def home():
    return render_template("main.html", title="Welcome to Flask")

# JSON API Endpoint
@app.route("/api/data")
def get_data():
    sample_data = {
        "name": "Flask App",
        "version": "1.0",
        "features": ["Jinja2 Templating", "REST API", "Lightweight"]
    }
    return jsonify(sample_data)

if __name__ == "__main__":
    app.run(debug=True)
