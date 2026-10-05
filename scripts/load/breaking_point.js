import http from 'k6/http';
import exec from 'k6/execution';

const API = __ENV.API_BASE_URL || 'http://localhost:4001/api/v1';
const MODE = __ENV.MODE || 'probe';
const RATE = Number(__ENV.RATE || 500);
const MEMBERS = Number(__ENV.MEMBERS || 1500);
const ADMIN = { email: __ENV.SEED_ADMIN_EMAIL || 'admin@example.com', password: __ENV.SEED_ADMIN_PASSWORD || 'ChangeMe-123' };
const STATE_FILE = '/scripts/results/breaking_point_state.json';
const PASSWORD = 'password-1';

http.setResponseCallback(http.expectedStatuses({ min: 200, max: 299 }));

const state = MODE === 'probe' ? JSON.parse(open(STATE_FILE)) : null;

const phase = (name, startTime, duration) => ({
  executor: 'constant-arrival-rate',
  exec: 'action',
  rate: RATE,
  timeUnit: '1s',
  duration,
  startTime,
  preAllocatedVUs: Math.min(RATE, 1500),
  maxVUs: 3000,
  tags: { phase: name },
});

export const options = {
  setupTimeout: '30m',
  scenarios: MODE === 'probe'
    ? { warmup: phase('warmup', '0s', '15s'), measure: phase('measure', '15s', '60s') }
    : { prepare: { executor: 'shared-iterations', exec: 'idle', vus: 1, iterations: 1 } },
  thresholds: MODE === 'probe'
    ? {
        'http_req_duration{phase:measure}': ['p(95)<500'],
        'http_req_failed{phase:measure}': ['rate<0.01'],
        'http_reqs{phase:measure}': ['count>=0'],
        'http_reqs{phase:measure,status:503}': ['count>=0'],
        'http_req_duration{phase:measure,expected_response:true}': ['p(95)>=0'],
        'iterations{phase:measure}': ['count>=0'],
        'dropped_iterations{scenario:measure}': ['count>=0'],
      }
    : {},
  summaryTrendStats: ['avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

const MIX = [['me', 80], ['updateName', 10], ['listUsers', 10]];
const MIX_TOTAL = MIX.reduce((sum, entry) => sum + entry[1], 0);

function request(method, path, body, token, name, ip) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (ip) headers['X-Forwarded-For'] = ip;
  return http.request(method, `${API}${path}`, body === null ? null : JSON.stringify(body), { headers, tags: { name } });
}

export function setup() {
  if (MODE === 'probe') return state;
  const admin = request('POST', '/auth/login', ADMIN, null, 'POST /auth/login', '10.255.0.1').json('token');
  const members = [];
  for (let start = 0; start < MEMBERS; start += 25) {
    const signups = [];
    const logins = [];
    for (let i = start; i < Math.min(start + 25, MEMBERS); i++) {
      const email = `bp.member.${i}@example.test`;
      const headers = { 'Content-Type': 'application/json', 'X-Forwarded-For': `10.220.${Math.floor(i / 250)}.${(i % 250) + 1}` };
      signups.push(['POST', `${API}/auth/signup`, JSON.stringify({ name: `Probe Member ${i}`, email, password: PASSWORD }), { headers }]);
      logins.push(['POST', `${API}/auth/login`, JSON.stringify({ email, password: PASSWORD }), { headers }]);
    }
    http.batch(signups);
    http.batch(logins).forEach((response) => {
      if (response.status === 200) members.push(response.json('token'));
    });
  }
  console.log(`prepare: ${members.length} members signed in`);
  return { admin, members };
}

export function idle() {}

const ACTIONS = {
  me(data) {
    request('GET', '/me', null, data.members[exec.vu.idInTest % data.members.length], 'GET /me');
  },
  updateName(data) {
    request('PATCH', '/me', { name: `Probe Member ${exec.vu.idInTest}` }, data.members[exec.vu.idInTest % data.members.length], 'PATCH /me');
  },
  listUsers(data) {
    request('GET', '/admin/users?limit=50', null, data.admin, 'GET /admin/users');
  },
};

export function action(data) {
  let roll = Math.random() * MIX_TOTAL;
  for (const [name, weight] of MIX) {
    roll -= weight;
    if (roll <= 0) {
      ACTIONS[name](data);
      return;
    }
  }
}

export function handleSummary(data) {
  if (MODE === 'prepare') return { [STATE_FILE]: JSON.stringify(data.setup_data) };
  return { [`/scripts/results/probe_${RATE}.json`]: JSON.stringify(data.metrics) };
}
