import io
import unittest

from PIL import Image

from app import app, garment_colour


def photo_bytes(colour=(200, 200, 200), size=(200, 400)):
    data = io.BytesIO()
    Image.new("RGB", size, colour).save(data, format="JPEG")
    data.seek(0)
    return data


class TryOnTest(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()

    def test_colour_comes_from_the_command_first(self):
        self.assertEqual(garment_colour("Red Lehenga", "make it blue"), (40, 80, 180))
        self.assertEqual(garment_colour("Red Lehenga", None), (190, 30, 45))

    def test_returns_a_png_with_the_garment_drawn(self):
        res = self.client.post("/try-on", data={
            "photo": (photo_bytes(), "me.jpg"), "garment_type": "Bridal Lehenga", "command": "Make it red",
        })
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.mimetype, "image/png")
        result = Image.open(io.BytesIO(res.data)).convert("RGB")
        centre = result.getpixel((100, 250))
        corner = result.getpixel((5, 5))
        self.assertGreater(centre[0], centre[2])
        self.assertAlmostEqual(corner[0], corner[2], delta=10)

    def test_rejects_a_missing_or_broken_photo(self):
        self.assertEqual(self.client.post("/try-on", data={}).status_code, 400)
        broken = {"photo": (io.BytesIO(b"not an image"), "x.jpg")}
        self.assertEqual(self.client.post("/try-on", data=broken).status_code, 400)


if __name__ == "__main__":
    unittest.main()
