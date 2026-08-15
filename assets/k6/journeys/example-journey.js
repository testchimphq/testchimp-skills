import http from 'k6/http';
import { check } from 'k6';
import { profileOptions } from '../profiles/index.js';
import { handleSummary } from '../lib/handleSummary.js';

export const options = profileOptions;
export { handleSummary };

export const testchimp = {
  id: 'example-journey',
  kind: 'journey',
  scenarios: [],
  testTypes: ['load'],
  operations: [],
  paths: ['/health'],
};

export default function () {
  const base = __ENV.BASE_URL || __ENV.BACKEND_URL || 'http://127.0.0.1:8080';
  const res = http.get(`${base}/health`);
  check(res, { 'status is 2xx': (r) => r.status >= 200 && r.status < 300 });
}
