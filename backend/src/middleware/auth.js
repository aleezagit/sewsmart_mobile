const jwt = require('jsonwebtoken');
const config = require('../config');
const User = require('../models/User');
const Admin = require('../models/Admin');
const { unauthorized, forbidden } = require('../utils/errors');

function signToken(subject, kind, tokenVersion, expiresIn = config.jwtExpiresIn) {
  return jwt.sign({ sub: subject, kind, ver: tokenVersion }, config.jwtSecret, { expiresIn });
}

function readToken(req) {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) throw unauthorized('Please sign in first');
  try {
    return jwt.verify(token, config.jwtSecret);
  } catch {
    throw unauthorized('Your session has expired. Please sign in again');
  }
}

// Signed-in customer, tailor or rider. Sets req.user.
async function requireUser(req, res, next) {
  const payload = readToken(req);
  if (payload.kind !== 'user') throw unauthorized('Please sign in with a SewSmart account');
  const user = await User.findById(payload.sub);
  if (!user || user.deleted_at || user.token_version !== payload.ver) throw unauthorized();
  if (user.status !== 'active') throw forbidden('Your account is suspended. Contact SewSmart support');
  req.user = user;
  next();
}

// Lets only the listed roles through. Use after requireUser.
function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) throw forbidden(`Only ${roles.join(' or ')} accounts can do this`);
    next();
  };
}

// Signed-in admin. Sets req.admin.
async function requireAdmin(req, res, next) {
  const payload = readToken(req);
  if (payload.kind !== 'admin') throw forbidden('Admin access only');
  const admin = await Admin.findById(payload.sub);
  if (!admin || admin.token_version !== payload.ver) throw unauthorized();
  req.admin = admin;
  next();
}

// Routes such as /api/tailors/:id/earnings name a user. Only that user may use them.
function requireSelf(param = 'id') {
  return (req, res, next) => {
    if (req.params[param] !== req.user.id) throw forbidden('You can only see your own account');
    next();
  };
}

module.exports = { signToken, requireUser, requireRole, requireAdmin, requireSelf };
