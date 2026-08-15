/**
 * Conservative example only. Policy/user-owned values override via env;
 * never derive absolute load from TestChimp or TrueCoverage observations.
 */
const positiveInt = (name, fallback) => {
  const value = Number.parseInt(__ENV[name] || '', 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
};

export const loadOptions = {
  vus: positiveInt('K6_LOAD_VUS', 10),
  duration: __ENV.K6_LOAD_DURATION || '30s',
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: [__ENV.K6_FAILED_THRESHOLD || 'rate<0.05'],
    http_req_duration: [__ENV.K6_DURATION_THRESHOLD || 'p(95)<800'],
  },
};
