/**
 * Data-volume: few concurrent users (default 1 VU) against a large seeded
 * dataset. Cardinality lives in the volume manifest / tenant `volumeSize`,
 * not VUs. Staircases hold 1 VU at each size (K6_VOLUME_STEPS) so Executions
 * can chart metrics against volume_size the way load charts them against VUs.
 * Journeys still call thinkTime() and recordVolumeSize (via pickTenant or
 * k6/lib/volume-size.js). Policy/user-owned settings override via env.
 *
 * Env: K6_VOLUME_DURATION / K6_VOLUME_STEP_DURATION (hold per step, default 1m),
 *      K6_VOLUME_STEPS (comma-separated sizes; omit for a single plateau),
 *      K6_VOLUME_SIZE (constant size when not stepping).
 */
function parseDurationMs(raw, fallbackMs) {
  if (!raw) return fallbackMs;
  const match = String(raw).trim().match(/^(\d+(?:\.\d+)?)(ms|s|m|h)$/i);
  if (!match) return fallbackMs;
  const n = Number(match[1]);
  const unit = match[2].toLowerCase();
  if (unit === 'ms') return n;
  if (unit === 's') return n * 1000;
  if (unit === 'm') return n * 60 * 1000;
  return n * 3600 * 1000;
}

function formatDuration(ms) {
  if (ms >= 3600000 && ms % 3600000 === 0) return `${ms / 3600000}h`;
  if (ms >= 60000 && ms % 60000 === 0) return `${ms / 60000}m`;
  if (ms >= 1000 && ms % 1000 === 0) return `${ms / 1000}s`;
  return `${Math.max(1, Math.round(ms))}ms`;
}

const stepDur = __ENV.K6_VOLUME_STEP_DURATION || __ENV.K6_VOLUME_DURATION || '1m';
const stepCount = Math.max(
  1,
  String(__ENV.K6_VOLUME_STEPS || '')
    .split(/[,\s]+/)
    .filter(Boolean).length
);

export const volumeOptions = {
  vus: 1,
  duration: formatDuration(parseDurationMs(stepDur, 60 * 1000) * stepCount),
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: [__ENV.K6_FAILED_THRESHOLD || 'rate<0.01'],
    http_req_duration: [__ENV.K6_DURATION_THRESHOLD || 'p(95)<1500'],
  },
};
