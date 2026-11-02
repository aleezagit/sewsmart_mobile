"""SewSmart virtual try-on service.

The Node API sends a full-body photo of the customer and a photo of the
garment here, and gets back an image of the customer wearing it. The picture
is made by a hosted try-on model (see vton.py).
"""
import io

from flask import Flask, jsonify, request, send_file
from PIL import Image, UnidentifiedImageError

import vton

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 12 * 1024 * 1024

provider = vton.Replicate()


def read_image(name):
    """The uploaded image called [name], or None when it is missing or broken."""
    upload = request.files.get(name)
    if upload is None:
        return None
    try:
        image = Image.open(upload.stream)
        image.load()
    except (UnidentifiedImageError, OSError):
        return None
    return image


@app.post("/try-on")
def try_on():
    person = read_image("photo")
    if person is None:
        return jsonify(message="A readable photo of the person is required"), 400
    garment = read_image("garment")
    if garment is None:
        return jsonify(message="A readable photo of the garment is required"), 400
    try:
        png = provider.try_on(person, garment, request.form.get("garment_type", ""), request.form.get("command"))
    except vton.NotConfigured as error:
        return jsonify(message=str(error)), 503
    except vton.TryOnTimeout as error:
        return jsonify(message=str(error)), 504
    except vton.TryOnFailed as error:
        return jsonify(message=str(error)), 502
    return send_file(io.BytesIO(png), mimetype="image/png")


@app.get("/health")
def health():
    return jsonify(status="ok", provider_configured=bool(provider.token))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
