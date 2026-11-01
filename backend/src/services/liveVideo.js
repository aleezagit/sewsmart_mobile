const { AccessToken } = require('livekit-server-sdk');
const config = require('../config');
const { HttpError } = require('../utils/errors');

// Video for live streams goes through LiveKit. The API only hands out
// short-lived tokens: the tailor's lets them publish into the stream's room,
// a viewer's lets them watch it. The secret never leaves the server.
const TOKEN_LIFETIME = '4h';

function configured() {
  const { url, apiKey, apiSecret } = config.livekit;
  return Boolean(url && apiKey && apiSecret);
}

async function videoToken({ streamId, user, publish }) {
  if (!configured()) {
    throw new HttpError(503, 'Live video is not set up on this server yet.');
  }
  const { url, apiKey, apiSecret } = config.livekit;
  const token = new AccessToken(apiKey, apiSecret, {
    identity: user.id,
    name: user.displayName || user.name,
    ttl: TOKEN_LIFETIME,
  });
  token.addGrant({
    room: streamId,
    roomJoin: true,
    canPublish: publish,
    canPublishData: false,
    canSubscribe: true,
  });
  return { url, token: await token.toJwt() };
}

module.exports = { configured, videoToken };
