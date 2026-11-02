const multer = require('multer');
const mongoose = require('mongoose');
const { HttpError } = require('../utils/errors');

function notFoundHandler(req, res) {
  res.status(404).json({ message: `No endpoint ${req.method} ${req.path}` });
}

// Every error becomes `{ "message": "..." }` with a matching status (docs/API.md, 1).
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  if (err instanceof HttpError) return res.status(err.status).json({ message: err.message });
  if (err instanceof multer.MulterError) {
    const message = err.code === 'LIMIT_FILE_SIZE' ? 'The file is larger than 5 MB' : err.message;
    return res.status(400).json({ message });
  }
  if (err instanceof mongoose.Error.ValidationError || err instanceof mongoose.Error.CastError) {
    return res.status(400).json({ message: err.message });
  }
  if (err.type === 'entity.parse.failed') return res.status(400).json({ message: 'The request body is not valid JSON' });
  if (err.code === 11000) return res.status(409).json({ message: 'This already exists' });
  console.error(err);
  return res.status(500).json({ message: 'Something went wrong. Please try again' });
}

module.exports = { notFoundHandler, errorHandler };
