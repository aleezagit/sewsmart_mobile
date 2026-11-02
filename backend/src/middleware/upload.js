const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const multer = require('multer');
const config = require('../config');
const { badRequest } = require('../utils/errors');

const IMAGE_TYPES = { 'image/jpeg': '.jpg', 'image/png': '.png' };
const MAX_BYTES = 5 * 1024 * 1024;

const root = path.resolve(config.uploadDir);

// Accepts JPEG and PNG images up to 5 MB into uploads/<folder>/.
function imageUpload(folder) {
  const dir = path.join(root, folder);
  fs.mkdirSync(dir, { recursive: true });
  return multer({
    storage: multer.diskStorage({
      destination: dir,
      filename: (req, file, cb) => cb(null, `${crypto.randomUUID()}${IMAGE_TYPES[file.mimetype]}`),
    }),
    limits: { fileSize: MAX_BYTES },
    fileFilter: (req, file, cb) => {
      if (IMAGE_TYPES[file.mimetype]) return cb(null, true);
      return cb(badRequest('Invalid file format. Only JPEG/PNG allowed'));
    },
  });
}

// The public address of an uploaded file.
function fileUrl(file) {
  const relative = path.relative(root, file.path).split(path.sep).join('/');
  return `${config.publicUrl}/uploads/${relative}`;
}

// Verification documents, one image per type (docs/API.md, 3.22).
const documentUpload = imageUpload('documents').fields(
  ['cnicFront', 'cnicBack', 'businessProof'].map((name) => ({ name, maxCount: 1 })),
);

// The uploaded documents of the given types as `{ type, url }`.
function uploadedDocuments(files, types) {
  return types.filter((type) => files?.[type]?.[0]).map((type) => ({ type, url: fileUrl(files[type][0]) }));
}

module.exports = { imageUpload, fileUrl, documentUpload, uploadedDocuments, uploadRoot: root };
