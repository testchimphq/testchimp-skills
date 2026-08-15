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
 * Deterministic external-dependency double for journey-side stubs.
 *
 * Prefer environment-level stubs (WireMock / stub containers / SUT config) so
 * the SUT still exercises its real clients. Use this helper when the k6
 * journey itself needs a controllable latency/error response.
 *
 * Defaults: 200 ms latency, no jitter, no errors — override per dependency.
 * Never ship load/volume journeys that stub externals at 0 ms unless the
 * approved plan explicitly documents that exception (false confidence risk).
 *
 * Env (optional global defaults):
 *   EXT_MOCK_LATENCY_MS, EXT_MOCK_JITTER_MS, EXT_MOCK_ERROR_RATE
 * Per-call overrides: { key, latencyMs, jitterMs, errorRate, status, body }
 */
export function mockExternal(dependencyName, overrides = {}) {
  const key = String(overrides.key || dependencyName || '');
  const latencyMs = overrides.latencyMs
    ?? numberFromEnv('EXT_MOCK_LATENCY_MS', 200, 0, 60000);
  const jitterMs = overrides.jitterMs
    ?? numberFromEnv('EXT_MOCK_JITTER_MS', 0, 0, 60000);
  const errorRate = overrides.errorRate
    ?? numberFromEnv('EXT_MOCK_ERROR_RATE', 0, 0, 1);
  const fraction = stableFraction(key);
  const deterministicJitter = Math.round((fraction * 2 - 1) * jitterMs);

  sleep(Math.max(0, latencyMs + deterministicJitter) / 1000);

  if (fraction < errorRate) {
    return {
      status: overrides.errorStatus ?? 503,
      body: overrides.errorBody ?? {
        error: 'deterministic_external_mock_error',
        dependency: dependencyName,
      },
    };
  }
  return {
    status: overrides.status ?? 200,
    body: overrides.body ?? {
      ok: true,
      dependency: dependencyName,
      mocked: true,
    },
  };
}
