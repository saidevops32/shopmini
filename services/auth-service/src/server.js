const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const { secret } = require('./config');
const { validEmail, validPassword } = require('./validate');

const PORT = process.env.PORT || 3000;
const JWT_SECRET = secret('jwt-secret', 'JWT_SECRET');
if (!JWT_SECRET) {
  console.error('jwt-secret is missing; refusing to start');
  process.exit(1);
}

const pool = new Pool({
  host: process.env.PG_HOST,
  port: 5432,
  user: process.env.PG_USER,
  database: process.env.PG_DB || 'authdb',
  password: secret('postgres-password', 'PG_PASSWORD'),
  ssl: { rejectUnauthorized: process.env.PG_SSL_VERIFY !== 'false' },
  max: 5,
  connectionTimeoutMillis: 5000,
});

let schemaReady = false;
let shuttingDown = false;

async function ensureSchema() {
  try {
    await pool.query(`create table if not exists users (
      id serial primary key,
      email text unique not null,
      password_hash text not null,
      created_at timestamptz not null default now())`);
    schemaReady = true;
    console.log('schema ready');
  } catch (e) {
    console.error('schema init failed:', e.code || e.message);
    setTimeout(ensureSchema, 5000);
  }
}

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '10kb' }));

// liveness: is the process alive? Never touches the database.
app.get('/health/live', (_req, res) => res.status(200).json({ status: 'up' }));

// readiness: can this pod serve traffic right now?
app.get('/health/ready', async (_req, res) => {
  if (shuttingDown) return res.status(503).json({ status: 'shutting down' });
  if (!schemaReady) return res.status(503).json({ status: 'schema not ready' });
  try {
    await pool.query('select 1');
    return res.status(200).json({ status: 'ready' });
  } catch {
    return res.status(503).json({ status: 'database unavailable' });
  }
});

app.post('/api/auth/register', async (req, res) => {
  const { email, password } = req.body || {};
  if (!validEmail(email) || !validPassword(password)) {
    return res.status(400).json({ error: 'invalid email, or password shorter than 8 characters' });
  }
  try {
    const hash = await bcrypt.hash(password, 10);
    const r = await pool.query(
      'insert into users(email, password_hash) values ($1, $2) returning id, email',
      [email.toLowerCase(), hash]);
    return res.status(201).json(r.rows[0]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'email already registered' });
    console.error('register failed:', e.code || e.message);
    return res.status(500).json({ error: 'internal error' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body || {};
  if (!validEmail(email) || typeof password !== 'string') {
    return res.status(400).json({ error: 'invalid request' });
  }
  try {
    const r = await pool.query('select id, password_hash from users where email = $1',
      [email.toLowerCase()]);
    const ok = r.rows[0] && await bcrypt.compare(password, r.rows[0].password_hash);
    if (!ok) return res.status(401).json({ error: 'invalid credentials' });
    const token = jwt.sign({ sub: String(r.rows[0].id) }, JWT_SECRET, { expiresIn: '1h' });
    return res.json({ token });
  } catch (e) {
    console.error('login failed:', e.code || e.message);
    return res.status(500).json({ error: 'internal error' });
  }
});

app.get('/api/auth/me', (req, res) => {
  const h = req.get('authorization') || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : '';
  try {
    const claims = jwt.verify(token, JWT_SECRET);
    return res.json({ userId: claims.sub });
  } catch {
    return res.status(401).json({ error: 'invalid or missing token' });
  }
});

const server = app.listen(PORT, () => console.log(`auth-service listening on ${PORT}`));
ensureSchema();

// graceful shutdown: stop being "ready", finish in-flight requests, then exit
function shutdown(signal) {
  console.log(`${signal} received, draining`);
  shuttingDown = true;
  server.close(() => pool.end().finally(() => process.exit(0)));
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
