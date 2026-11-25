import http from 'k6/http';
import { check, sleep } from 'k6';

// Recovery profile: a short, steep spike followed by a rapid ramp-down. The
// thresholds are stress guardrails, not the API SLO; calibrate them with
// TODO(measure) after a real baseline exists.
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const ITEMS_URL = `${BASE_URL}/items`;

export const options = {
  discardResponseBodies: true,
  stages: [
    { duration: '30s', target: 5 },
    { duration: '10s', target: 100 },
    { duration: '30s', target: 100 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'],
    checks: ['rate>0.95'],
    http_req_duration: ['p(95)<2000'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(95)', 'p(99)', 'max'],
};

export default function () {
  const response = http.get(ITEMS_URL, { tags: { name: 'GET /items' } });
  check(response, {
    'GET /items returns 200': (response) => response.status === 200,
  });
  sleep(0.1);
}
