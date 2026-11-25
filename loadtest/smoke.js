import http from 'k6/http';
import { check, sleep } from 'k6';

// Functional gate before the longer load profiles. BASE_URL defaults to the
// kind ingress on localhost; override it for EKS with BASE_URL=https://...
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const ITEMS_URL = `${BASE_URL}/items`;

export const options = {
  vus: 1,
  duration: __ENV.SMOKE_DURATION || '30s',
  thresholds: {
    http_req_failed: ['rate==0'],
    checks: ['rate==1'],
    http_req_duration: ['p(95)<500'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(95)', 'max'],
};

export default function () {
  const response = http.get(ITEMS_URL, { tags: { name: 'GET /items' } });
  check(response, {
    'GET /items returns 200': (response) => response.status === 200,
  });
  sleep(1);
}
