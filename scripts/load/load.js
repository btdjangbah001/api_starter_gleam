import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';

const API = __ENV.API_BASE_URL || 'http://localhost:4001/api/v1';
const SMOKE = __ENV.SMOKE === '1';
const MEMBERS = SMOKE ? 20 : 700;
const ADMIN = { email: __ENV.SEED_ADMIN_EMAIL || 'admin@example.com', password: __ENV.SEED_ADMIN_PASSWORD || 'ChangeMe-123' };
const PASSWORD = 'password-1';
const RUN = SMOKE ? '1m' : '20m';
const MEMBER_STAGES = SMOKE
  ? [{ duration: '20s', target: 10 }, { duration: '30s', target: 10 }, { duration: '10s', target: 0 }]
  : [
      { duration: '2m', target: 100 },
      { duration: '3m', target: 300 },
      { duration: '8m', target: 300 },
      { duration: '2m', target: 600 },
      { duration: '3m', target: 600 },
      { duration: '2m', target: 0 },
    ];

http.setResponseCallback(http.expectedStatuses({ min: 200, max: 299 }));

export const options = {
  setupTimeout: '15m',
  scenarios: {
    members: { executor: 'ramping-vus', exec: 'memberSession', startVUs: 0, stages: MEMBER_STAGES, gracefulRampDown: '30s' },
    admins: { executor: 'constant-vus', exec: 'adminConsole', vus: 2, duration: RUN },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    checks: ['rate>0.99'],
    'http_req_duration{kind:poll}': ['p(95)<200'],
    'http_req_duration{kind:write}': ['p(95)<500'],
    'http_req_duration{kind:auth}': ['p(95)<800'],
  },
  summaryTrendStats: ['avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

function request(method, path, body, token, name, kind, ip) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (ip) headers['X-Forwarded-For'] = ip;
  return http.request(method, `${API}${path}`, body === null ? null : JSON.stringify(body), { headers, tags: { name, kind } });
}

function think(min, max) {
  sleep(min + Math.random() * (max - min));
}

function login(email, password, ip) {
  const response = request('POST', '/auth/login', { email, password }, null, 'POST /auth/login', 'auth', ip);
  check(response, { 'login succeeded': (r) => r.status === 200 });
  return response.status === 200 ? response.json('token') : null;
}

export function setup() {
  for (let start = 0; start < MEMBERS; start += 25) {
    const batch = [];
    for (let i = start; i < Math.min(start + 25, MEMBERS); i++) {
      batch.push(['POST', `${API}/auth/signup`, JSON.stringify({ name: `Load Member ${i}`, email: `load.member.${i}@example.test`, password: PASSWORD }), {
        headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': `10.200.${Math.floor(i / 250)}.${(i % 250) + 1}` },
        tags: { name: 'POST /auth/signup', kind: 'auth' },
      }]);
    }
    http.batch(batch);
  }
  return { admin: login(ADMIN.email, ADMIN.password, '10.255.0.1') };
}

export function memberSession() {
  const index = exec.vu.idInTest % MEMBERS;
  const ip = `10.${100 + (index % 100)}.${Math.floor(index / 100)}.${(exec.vu.iterationInScenario % 250) + 1}`;
  const token = login(`load.member.${index}@example.test`, PASSWORD, ip);
  if (!token) {
    think(10, 20);
    return;
  }
  const polls = 6 + Math.floor(Math.random() * 12);
  for (let i = 0; i < polls; i++) {
    const me = request('GET', '/me', null, token, 'GET /me', 'poll');
    check(me, { 'profile loaded': (r) => r.status === 200 });
    if (Math.random() < 0.05) request('PATCH', '/me', { name: `Load Member ${index}` }, token, 'PATCH /me', 'write');
    sleep(5);
  }
  if (Math.random() < 0.3) request('POST', '/auth/logout', null, token, 'POST /auth/logout', 'auth');
  think(5, 15);
}

export function adminConsole(data) {
  for (let round = 0; round < 6; round++) {
    request('GET', '/admin/users?limit=50', null, data.admin, 'GET /admin/users', 'poll');
    sleep(10);
  }
}

export function handleSummary(data) {
  return {
    stdout: textSummary(data, { indent: ' ', enableColors: false }),
    '/scripts/results/load_summary.json': JSON.stringify(data, null, 2),
  };
}
