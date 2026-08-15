/**
 * Data-volume example: few concurrent users (default 1 VU) against a large
 * seeded dataset. Cardinality lives in the volume manifest, not VUs.
 * Journeys still call thinkTime() so this is one user working the data, not
 * a tight request loop. Policy/user-owned settings override via env.
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
