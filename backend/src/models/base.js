const mongoose = require('mongoose');

// Every API object has a string `id` and no `_id` or `__v` (docs/API.md, 1).
// `hidden` lists fields that never leave the server, such as password hashes.
function createSchema(definition, { hidden = [], timestamps = true, stringId = true } = {}) {
  const schema = new mongoose.Schema(
    stringId ? { _id: { type: String, required: true }, ...definition } : definition,
    {
      versionKey: false,
      timestamps: timestamps ? { createdAt: 'created_at', updatedAt: 'updated_at' } : false,
      toJSON: {
        transform(doc, ret) {
          ret.id = String(ret._id);
          delete ret._id;
          delete ret.updated_at;
          for (const field of hidden) delete ret[field];
          return ret;
        },
      },
    },
  );
  return schema;
}

module.exports = { createSchema, mongoose };
