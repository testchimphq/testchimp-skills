import http from 'k6/http';
import { check } from 'k6';
import { profileOptions } from '../profiles/index.js';
import { handleSummary } from '../lib/handleSummary.js';

export const options = profileOptions;
export { handleSummary };

export const testchimp = {
  id: 'example-composite',
  kind: 'composite',
  scenarios: [],
  testTypes: ['load'],
  members: ['example-journey'],
};

// Replace this sample with approved weighted member executors. Membership
// metadata is explicit so TestChimp can preserve the composite relationship.
export default function () {
  const base = __ENV.BASE_URL || __ENV.BACKEND_URL || 'http://127.0.0.1:8080';
  const response = http.get(`${base}/health`);
  check(response, { 'composite health status is 2xx': (r) => r.status >= 200 && r.status < 300 });
}
