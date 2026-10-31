"""Calls a hosted virtual try-on model on Replicate.

The model gets a photo of the person and a photo of the garment and returns
the person wearing it. The default model is IDM-VTON. Set REPLICATE_MODEL to
use another one with the same inputs (human_img, garm_img, garment_des,
category).
"""
import base64
import io
import os
import time

import requests
from PIL import Image

API = "https://api.replicate.com/v1"
DEFAULT_MODEL = "cuuupid/idm-vton"
# Photos are scaled down before they are sent: the model works at this size.
MAX_SIDE = 1024
# The longest wait for the model, in seconds. A try-on takes about 20 to 60.
DEADLINE = 150

# Words in the garment type that tell the model which part of the body to dress.
LOWER = ("trouser", "pants", "palazzo", "jeans", "skirt", "shalwar", "salwar")
UPPER = ("shirt", "kameez", "kurta", "top", "blazer", "jacket", "blouse")


class NotConfigured(Exception):
    """No REPLICATE_API_TOKEN is set."""


class TryOnFailed(Exception):
    """The model could not produce an image. The message can be shown."""


class TryOnTimeout(Exception):
    """The model did not answer in time."""


def category(garment_type):
    """upper_body, lower_body or dresses, from the garment type."""
    name = (garment_type or "").lower()
    if any(word in name for word in LOWER):
        return "lower_body"
    if any(word in name for word in UPPER):
        return "upper_body"
    return "dresses"


def data_uri(image):
    """The image as a JPEG data URI, at most MAX_SIDE on its longest side."""
    image = image.convert("RGB")
    image.thumbnail((MAX_SIDE, MAX_SIDE))
    out = io.BytesIO()
    image.save(out, format="JPEG", quality=90)
    return "data:image/jpeg;base64," + base64.b64encode(out.getvalue()).decode()


class Replicate:
    def __init__(self, token=None, model=None, session=None):
        self.token = token if token is not None else os.environ.get("REPLICATE_API_TOKEN", "")
        self.model = model or os.environ.get("REPLICATE_MODEL", DEFAULT_MODEL)
        self.http = session or requests.Session()
        self._version = None

    def _headers(self, **extra):
        return {"Authorization": f"Bearer {self.token}", **extra}

    def _call(self, method, url, **kwargs):
        try:
            response = self.http.request(method, url, timeout=70, **kwargs)
        except requests.RequestException as error:
            raise TryOnFailed("The try-on provider could not be reached") from error
        if response.status_code == 401:
            raise NotConfigured("The REPLICATE_API_TOKEN is not valid")
        if response.status_code == 402:
            raise TryOnFailed("The try-on provider account has no credit left")
        if response.status_code == 429:
            raise TryOnFailed("The try-on provider is busy. Try again in a minute")
        if not response.ok:
            raise TryOnFailed("The try-on provider refused the request")
        return response

    def version(self):
        """The latest version of the model, found once."""
        if self._version is None:
            response = self._call("GET", f"{API}/models/{self.model}", headers=self._headers())
            self._version = response.json()["latest_version"]["id"]
        return self._version

    def try_on(self, person, garment, garment_type, description):
        """The PNG bytes of [person] wearing [garment]."""
        if not self.token:
            raise NotConfigured("REPLICATE_API_TOKEN is not set")
        kind = category(garment_type)
        body = {
            "version": self.version(),
            "input": {
                "human_img": data_uri(person),
                "garm_img": data_uri(garment),
                "garment_des": (description or garment_type or "garment")[:200],
                "category": kind,
                "crop": False,
                "steps": 30,
                "force_dc": kind == "dresses",
            },
        }
        # Prefer: wait holds the request until the model is done, up to 60 seconds.
        prediction = self._call(
            "POST", f"{API}/predictions", json=body, headers=self._headers(Prefer="wait=60"),
        ).json()
        deadline = time.monotonic() + DEADLINE
        while prediction["status"] in ("starting", "processing"):
            if time.monotonic() > deadline:
                raise TryOnTimeout("The try-on took too long")
            time.sleep(2)
            prediction = self._call("GET", prediction["urls"]["get"], headers=self._headers()).json()
        if prediction["status"] != "succeeded":
            raise TryOnFailed("The try-on could not be made from these photos. Try clearer ones")
        output = prediction["output"]
        url = output[0] if isinstance(output, list) else output
        image = self._call("GET", url).content
        out = io.BytesIO()
        Image.open(io.BytesIO(image)).convert("RGB").save(out, format="PNG")
        return out.getvalue()
