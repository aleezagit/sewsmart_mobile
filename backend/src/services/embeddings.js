const config = require('../config');

// Text turned into lists of numbers (embeddings) by Google's Gemini API, so
// that texts with a similar meaning end up close together, whatever the
// spelling or language ("lehnga", "bridal dress" and "shaadi ka joda").
// Without GEMINI_API_KEY, or when Gemini does not answer, embed() gives null
// and callers fall back to keyword matching. A failure never stops a request.
const DIMENSIONS = 768;
const BATCH = 100;

const configured = () => Boolean(config.geminiApiKey);
const modelId = () => `${config.geminiEmbeddingModel}:${DIMENSIONS}`;

function normalize(values) {
  const length = Math.hypot(...values);
  return length ? values.map((value) => value / length) : values;
}

// Vectors of length 1, so the dot product of two is their cosine similarity.
// taskType is RETRIEVAL_DOCUMENT for designs and RETRIEVAL_QUERY for searches.
async function embed(texts, taskType) {
  if (!configured() || !texts.length) return null;
  const model = config.geminiEmbeddingModel;
  const vectors = [];
  try {
    for (let i = 0; i < texts.length; i += BATCH) {
      const chunk = texts.slice(i, i + BATCH);
      const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:batchEmbedContents`, {
        method: 'POST',
        headers: { 'x-goog-api-key': config.geminiApiKey, 'content-type': 'application/json' },
        body: JSON.stringify({
          requests: chunk.map((text) => ({
            model: `models/${model}`,
            content: { parts: [{ text }] },
            taskType,
            outputDimensionality: DIMENSIONS,
          })),
        }),
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok) {
        console.error(`Gemini refused the embedding request (${response.status}): ${await response.text()}`);
        return null;
      }
      const { embeddings = [] } = await response.json();
      if (embeddings.length !== chunk.length) return null;
      vectors.push(...embeddings.map((item) => normalize(item.values)));
    }
    return vectors;
  } catch (error) {
    console.error(`Gemini embedding request failed: ${error.message}`);
    return null;
  }
}

const similarity = (a, b) => a.reduce((sum, value, i) => sum + value * b[i], 0);

module.exports = { embed, similarity, normalize, configured, modelId };
