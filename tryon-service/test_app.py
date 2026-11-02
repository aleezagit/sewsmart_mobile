import base64
import io
import unittest

import requests
from PIL import Image

import app as service
import vton


def png(colour, size=(200, 400)):
    data = io.BytesIO()
    Image.new("RGB", size, colour).save(data, format="PNG")
    return data.getvalue()


def upload(colour=(200, 200, 200)):
    return io.BytesIO(png(colour))


class FakeResponse:
    def __init__(self, status=200, body=None, content=b""):
        self.status_code, self._body, self.content = status, body, content
        self.ok = 200 <= status < 300

    def json(self):
        return self._body


class FakeReplicate:
    """Answers like api.replicate.com and remembers the requests it got."""

    def __init__(self, polls=0, final="succeeded", status=200, fail_download=False):
        self.calls, self.polls, self.final, self.status = [], polls, final, status
        self.result = png((10, 120, 30))
        self.fail_download = fail_download

    def request(self, method, url, **kwargs):
        self.calls.append((method, url, kwargs))
        if self.status != 200:
            return FakeResponse(self.status)
        if url.endswith("/models/cuuupid/idm-vton"):
            return FakeResponse(body={"latest_version": {"id": "v123"}})
        if method == "POST" and url.endswith("/predictions"):
            state = "processing" if self.polls else self.final
            return FakeResponse(body=self._prediction(state))
        if url.endswith("/predictions/p1"):
            self.polls -= 1
            return FakeResponse(body=self._prediction("processing" if self.polls > 0 else self.final))
        if url == "https://files/out.png":
            if self.fail_download:
                raise requests.ConnectionError()
            return FakeResponse(content=self.result)
        raise AssertionError(f"unexpected request {method} {url}")

    @staticmethod
    def _prediction(state):
        return {"id": "p1", "status": state, "output": "https://files/out.png" if state == "succeeded" else None,
                "urls": {"get": "https://api.replicate.com/v1/predictions/p1"}}


class TryOnTest(unittest.TestCase):
    def setUp(self):
        self.client = service.app.test_client()
        self.fake = FakeReplicate()
        service.provider = vton.Replicate(token="secret", session=self.fake)
        self._sleep, vton.time.sleep = vton.time.sleep, lambda _: None

    def tearDown(self):
        vton.time.sleep = self._sleep

    def post(self, **fields):
        data = {"photo": (upload(), "me.png"), "garment": (upload((180, 20, 40)), "dress.png"),
                "garment_type": "Bridal Lehenga", "command": "Make it red", **fields}
        return self.client.post("/try-on", data=data)

    def test_sends_both_photos_and_returns_the_model_result(self):
        res = self.post()
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.mimetype, "image/png")
        self.assertEqual(Image.open(io.BytesIO(res.data)).getpixel((5, 5)), (10, 120, 30))
        method, url, kwargs = next(c for c in self.fake.calls if c[0] == "POST")
        self.assertEqual(kwargs["headers"]["Authorization"], "Bearer secret")
        sent = kwargs["json"]
        self.assertEqual(sent["version"], "v123")
        self.assertEqual(sent["input"]["category"], "dresses")
        self.assertEqual(sent["input"]["garment_des"], "Make it red")
        for key in ("human_img", "garm_img"):
            self.assertTrue(sent["input"][key].startswith("data:image/jpeg;base64,"))
            Image.open(io.BytesIO(base64.b64decode(sent["input"][key].split(",")[1])))

    def test_waits_for_a_slow_model(self):
        self.fake.polls = 3
        self.assertEqual(self.post().status_code, 200)

    def test_category_follows_the_garment_type(self):
        self.assertEqual(vton.category("Bridal Lehenga"), "dresses")
        self.assertEqual(vton.category("Formal Shirt"), "upper_body")
        self.assertEqual(vton.category("Palazzo"), "lower_body")
        self.assertEqual(vton.category(""), "dresses")

    def test_rejects_missing_or_broken_photos(self):
        self.assertEqual(self.client.post("/try-on", data={}).status_code, 400)
        only_person = {"photo": (upload(), "me.png")}
        self.assertEqual(self.client.post("/try-on", data=only_person).status_code, 400)
        broken = {"photo": (upload(), "me.png"), "garment": (io.BytesIO(b"not an image"), "x.png")}
        self.assertEqual(self.client.post("/try-on", data=broken).status_code, 400)

    def test_without_a_token_it_is_not_available(self):
        service.provider = vton.Replicate(token="", session=self.fake)
        self.assertEqual(self.post().status_code, 503)
        self.assertEqual(self.fake.calls, [])

    def test_provider_errors_become_messages(self):
        for status, expected in ((401, 503), (402, 502), (429, 502), (500, 502)):
            service.provider = vton.Replicate(token="secret", session=FakeReplicate(status=status))
            self.assertEqual(self.post().status_code, expected, status)
        service.provider = vton.Replicate(token="secret", session=FakeReplicate(final="failed"))
        res = self.post()
        self.assertEqual(res.status_code, 502)
        self.assertIn("clearer", res.get_json()["message"])

    def test_a_model_that_never_finishes_times_out(self):
        self.fake.polls = 10 ** 6
        original, vton.DEADLINE = vton.DEADLINE, -1
        try:
            self.assertEqual(self.post().status_code, 504)
        finally:
            vton.DEADLINE = original

    def test_health_reports_whether_the_provider_is_configured(self):
        self.assertTrue(self.client.get("/health").get_json()["provider_configured"])


if __name__ == "__main__":
    unittest.main()
