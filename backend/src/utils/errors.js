// An error with an HTTP status. The error handler turns it into
// `{ "message": "..." }` with that status.
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

module.exports = {
  HttpError,
  badRequest: (message) => new HttpError(400, message),
  unauthorized: (message = 'Please sign in again') => new HttpError(401, message),
  forbidden: (message = 'You are not allowed to do this') => new HttpError(403, message),
  notFound: (message = 'Not found') => new HttpError(404, message),
  conflict: (message) => new HttpError(409, message),
};
