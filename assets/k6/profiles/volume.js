/**
 * Data-volume example (few VUs; dataset cardinality lives in its manifest).
 * Policy/user-owned settings override via env.
 */
export const volumeOptions = {
  vus: 1,
  duration: __ENV.K6_VOLUME_DURATION || '1m',
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: [__ENV.K6_FAILED_THRESHOLD || 'rate<0.01'],
    http_req_duration: [__ENV.K6_DURATION_THRESHOLD || 'p(95)<1500'],
  },
};
