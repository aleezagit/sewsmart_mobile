"""SewSmart virtual try-on service.

The Node API sends a customer's full-body photo here and gets back a preview
of the garment on the photo. The garment is drawn as a shaped, coloured layer
blended over the body area, so the photo's light and folds show through it.
"""
import io
import re

from flask import Flask, jsonify, request, send_file
from PIL import Image, ImageChops, ImageDraw, ImageFilter, UnidentifiedImageError

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024

COLOURS = {
    "red": (190, 30, 45), "maroon": (110, 20, 35), "pink": (230, 120, 160), "orange": (235, 120, 40),
    "yellow": (240, 200, 60), "gold": (212, 175, 55), "golden": (212, 175, 55), "green": (40, 140, 80),
    "teal": (20, 130, 130), "blue": (40, 80, 180), "navy": (25, 35, 90), "purple": (110, 50, 150),
    "black": (30, 30, 35), "white": (240, 240, 235), "cream": (240, 225, 195), "grey": (130, 130, 135),
    "gray": (130, 130, 135), "brown": (120, 75, 45), "peach": (250, 180, 140),
}

# Garments that flare out below the waist.
FLARED = ("lehenga", "frock", "anarkali", "gown", "maxi", "sharara", "gharara", "dress")
# Garments that stop at the hips.
SHORT = ("shirt", "kurta", "top", "blazer", "jacket")

MAX_SIDE = 1024


def garment_colour(garment_type, command):
    """The first colour named in the command, else in the garment type, else maroon."""
    for text in (command or "", garment_type or ""):
        for word in re.findall(r"[a-z]+", text.lower()):
            if word in COLOURS:
                return COLOURS[word]
    return COLOURS["maroon"]


def garment_outline(width, height, garment_type):
    """Polygon of the garment over a standing figure centred in the photo."""
    name = (garment_type or "").lower()
    cx = width / 2
    shoulder_y, waist_y = height * 0.22, height * 0.48
    shoulder, waist = width * 0.20, width * 0.15
    if any(word in name for word in SHORT):
        hem_y, hem = height * 0.62, width * 0.19
    elif any(word in name for word in FLARED):
        hem_y, hem = height * 0.93, width * 0.34
    else:
        hem_y, hem = height * 0.80, width * 0.21
    return [
        (cx - shoulder, shoulder_y), (cx + shoulder, shoulder_y),
        (cx + waist, waist_y), (cx + hem, hem_y),
        (cx - hem, hem_y), (cx - waist, waist_y),
    ]


def render(photo, garment_type, command):
    photo = photo.convert("RGB")
    photo.thumbnail((MAX_SIDE, MAX_SIDE))
    width, height = photo.size

    mask = Image.new("L", photo.size, 0)
    ImageDraw.Draw(mask).polygon(garment_outline(width, height, garment_type), fill=210)
    mask = mask.filter(ImageFilter.GaussianBlur(max(2, width // 120)))

    # Multiplying a light version of the photo by the colour keeps its shading.
    shading = ImageChops.screen(photo.convert("L").convert("RGB"), Image.new("RGB", photo.size, (70, 70, 70)))
    fabric = ImageChops.multiply(shading, Image.new("RGB", photo.size, garment_colour(garment_type, command)))
    return Image.composite(fabric, photo, mask)


@app.post("/try-on")
def try_on():
    upload = request.files.get("photo")
    if upload is None:
        return jsonify(message="photo is required"), 400
    try:
        photo = Image.open(upload.stream)
        photo.load()
    except (UnidentifiedImageError, OSError):
        return jsonify(message="The photo could not be read"), 400

    result = render(photo, request.form.get("garment_type", ""), request.form.get("command"))
    output = io.BytesIO()
    result.save(output, format="PNG")
    output.seek(0)
    return send_file(output, mimetype="image/png")


@app.get("/health")
def health():
    return jsonify(status="ok")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
