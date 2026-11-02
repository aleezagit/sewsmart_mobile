const express = require('express');
const DesignPicture = require('../models/DesignPicture');
const { notFound } = require('../utils/errors');

// A catalogue design's picture. It is open, because the apps show it with a plain
// image widget that sends no token, and it holds nothing private. The link carries
// a ?v= that changes with the picture, so it can be cached for a long time.
const router = express.Router();

router.get('/:id/image', async (req, res) => {
  const picture = await DesignPicture.findById(req.params.id);
  if (!picture) throw notFound('Picture not found');
  res.set('Content-Type', picture.content_type).set('Cache-Control', 'public, max-age=31536000, immutable').send(picture.data);
});

module.exports = router;
