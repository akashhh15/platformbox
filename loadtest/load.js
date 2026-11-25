import http from 'k6/http';
import { check, sleep } from 'k6';

// Sustained profile for HPA observation. The five-minute plateau is long
// enough for several HPA sync periods; see docs/resilience.md.
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const ITEMS_URL = `${BASE_URL}/items`;

export const options = {
  discardResponseBodies: true,
  stages: [
    { duration: '1m', target: 10 },
    { duration: '5m', target: 50 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    // Provisional values from ADR-024; replace after TODO(measure).
    http_req_failed: ['rate<0.005'],
    checks: ['rate>0.99'],
    http_req_duration: ['p(95)<500'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(95)', 'p(99)', 'max'],
};

export default function () {
  const response = http.get(ITEMS_URL, { tags: { name: 'GET /items' } });
  check(response, {
    'GET /items returns 200': (response) => response.status === 200,
  });
  sleep(0.2);
}
