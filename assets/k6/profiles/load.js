/**
 * Load = N concurrent users completing the journey (not an open-loop RPS
 * hammer). ramping-vus starts low so Executions charts show metric change
 * as concurrency climbs to K6_LOAD_VUS (peak). Conservative example only —
 * policy/user-owned values override via env; never derive absolute load from
 * TestChimp or TrueCoverage observations.
 *
 * Env:
 *   K6_LOAD_VUS       peak concurrent users (default 10)
 *   K6_LOAD_RAMP      duration of each ramp step (default 30s)
 *   K6_LOAD_DURATION  hold at peak (default 1m)
 */
const positiveInt = (name, fallback) => {
  const value = Number.parseInt(__ENV[name] || '', 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
};

function loadStages(peak, ramp, hold) {
  const p = Math.max(1, peak);
  const low = Math.max(1, Math.round(p * 0.1));
  const mid = Math.max(low, Math.round(p * 0.5));
  const stages = [];
  if (low < p) stages.push({ duration: ramp, target: low });
  if (mid > low && mid < p) stages.push({ duration: ramp, target: mid });
  stages.push({ duration: ramp, target: p });
  stages.push({ duration: hold, target: p });
  stages.push({ duration: ramp, target: 0 });
  return stages;
}

const peakVus = positiveInt('K6_LOAD_VUS', 10);

export const loadOptions = {
  scenarios: {
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: loadStages(
        peakVus,
        __ENV.K6_LOAD_RAMP || '30s',
        __ENV.K6_LOAD_DURATION || '1m'
      ),
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: [__ENV.K6_FAILED_THRESHOLD || 'rate<0.05'],
    http_req_duration: [__ENV.K6_DURATION_THRESHOLD || 'p(95)<800'],
  },
};
