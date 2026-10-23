import { Gauge } from 'k6/metrics';

/**
 * Dataset cardinality for volume runs. Executions charts this instead of VUs
 * (volume stays at 1 VU). Emit the size of the tenant you are about to hit.
 *
 * Multi-tenant staircases: put `volumeSize` on each tenant (small → large) and
 * call `pickSteppedVolumeTenant` + `recordVolumeSize` from `pickTenant`/default.
 * Single-size runs: `recordVolumeSize(n)` or `K6_VOLUME_SIZE`.
 *
 * Env: K6_VOLUME_STEPS (comma sizes), K6_VOLUME_STEP_DURATION / K6_VOLUME_DURATION.
 */
export const volumeSize = new Gauge('volume_size');

let startedAtMs = 0;

export function parseDurationMs(raw, fallbackMs) {
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

export function parseVolumeSteps(raw) {
  return String(raw || '')
    .split(/[,\s]+/)
    .map((part) => Number(part))
    .filter((n) => Number.isFinite(n) && n >= 0);
}

export function currentVolumeStepIndex(stepCount) {
  if (!startedAtMs) startedAtMs = Date.now();
  if (!stepCount || stepCount <= 1) return 0;
  const stepMs = parseDurationMs(
    __ENV.K6_VOLUME_STEP_DURATION || __ENV.K6_VOLUME_DURATION,
    60 * 1000
  );
  const elapsed = Date.now() - startedAtMs;
  return Math.min(stepCount - 1, Math.max(0, Math.floor(elapsed / Math.max(1, stepMs))));
}

export function steppedVolumeTenants(tenants) {
  return (tenants || [])
    .filter((t) => t && typeof t.volumeSize === 'number' && Number.isFinite(t.volumeSize))
    .slice()
    .sort((a, b) => a.volumeSize - b.volumeSize);
}

export function pickSteppedVolumeTenant(tenants) {
  const sized = steppedVolumeTenants(tenants);
  if (!sized.length) return null;
  return sized[currentVolumeStepIndex(sized.length)];
}

export function recordVolumeSize(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    volumeSize.add(value);
    return value;
  }
  // Honest plateau only. K6_VOLUME_STEPS is duration/step count — never fake a
  // ramp against data that did not change.
  const single = Number(__ENV.K6_VOLUME_SIZE || '');
  if (Number.isFinite(single) && single >= 0) {
    volumeSize.add(single);
    return single;
  }
  return undefined;
}
