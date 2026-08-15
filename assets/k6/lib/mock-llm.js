import { sleep } from 'k6';

const numberFromEnv = (name, fallback, min, max) => {
  const value = Number(__ENV[name]);
  return Number.isFinite(value) ? Math.min(max, Math.max(min, value)) : fallback;
};

const stableFraction = (text) => {
  let hash = 2166136261;
  for (let i = 0; i < text.length; i += 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) / 4294967296;
};

/**
 * Deterministic LLM double. Defaults: 250 ms latency, no jitter/errors.
 * Configure with LLM_MOCK_LATENCY_MS, LLM_MOCK_JITTER_MS,
 * LLM_MOCK_ERROR_RATE, and LLM_MOCK_RESPONSE.
 *
 * LLMs are one case of external deps — see mock-external.js and
 * references/perf-testing.md § External dependencies. Do not use 0 ms
 * latency for load/volume (false confidence).
 */
export function mockLlm(prompt, overrides = {}) {
  const key = String(overrides.key || prompt || '');
  const latencyMs = overrides.latencyMs
    ?? numberFromEnv('LLM_MOCK_LATENCY_MS', 250, 0, 60000);
  const jitterMs = overrides.jitterMs
    ?? numberFromEnv('LLM_MOCK_JITTER_MS', 0, 0, 60000);
  const errorRate = overrides.errorRate
    ?? numberFromEnv('LLM_MOCK_ERROR_RATE', 0, 0, 1);
  const fraction = stableFraction(key);
  const deterministicJitter = Math.round((fraction * 2 - 1) * jitterMs);

  sleep(Math.max(0, latencyMs + deterministicJitter) / 1000);

  if (fraction < errorRate) {
    return { status: 503, body: { error: 'deterministic_mock_error' } };
  }
  return {
    status: 200,
    body: {
      id: `mock-${Math.floor(fraction * 1e9).toString(36)}`,
      output: overrides.response ?? __ENV.LLM_MOCK_RESPONSE ?? 'mocked response',
    },
  };
}
