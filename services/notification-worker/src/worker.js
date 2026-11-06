const http = require('node:http');
const amqp = require('amqplib');
const { secret } = require('./config');
const { createHandler } = require('./handler');

// must match checkout-service (Messaging.java): same names, same settings
const EXCHANGE = 'shop.events';
const QUEUE = 'notification.order-created';
const ROUTING_KEY = 'order.created';
const HEALTH_PORT = Number(process.env.PORT || 3001);

const password = secret('rabbitmq-password', 'RABBITMQ_PASSWORD');
if (!password) {
  console.error('rabbitmq-password is missing; refusing to start');
  process.exit(1);
}

const handle = createHandler((e) =>
  // JSON.stringify keeps every logged value on one escaped line
  console.log(JSON.stringify({ msg: 'order confirmation sent', orderId: e.orderId, userId: e.userId, total: e.total })));

let connection = null;
let channel = null;
let consumerTag = null;
let ready = false;
let shuttingDown = false;
let attempt = 0;
let timer = null;

// liveness: the process is alive. readiness: connected and consuming.
const health = http.createServer((req, res) => {
  const send = (code, body) => {
    res.writeHead(code, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body));
  };
  if (req.url === '/health/live') return send(200, { status: 'up' });
  if (req.url === '/health/ready') {
    const ok = ready && !shuttingDown;
    return send(ok ? 200 : 503, { status: ok ? 'ready' : 'not ready' });
  }
  return send(404, { error: 'not found' });
});
health.listen(HEALTH_PORT, () => console.log(`health endpoints on ${HEALTH_PORT}`));

function scheduleReconnect() {
  if (timer || shuttingDown) return;
  const delay = Math.min(30000, 1000 * 2 ** attempt++);
  console.log(`reconnecting to rabbitmq in ${delay} ms`);
  timer = setTimeout(() => { timer = null; start(); }, delay);
}

function onMessage(ch, msg) {
  if (msg === null) {                     // the broker cancelled our consumer
    ready = false;
    ch.close().catch(() => {});
    return;
  }
  try {
    const result = handle(msg.content);
    if (result === 'invalid') {
      console.warn(JSON.stringify({ msg: 'dropping malformed message', bytes: msg.content.length }));
    } else if (result === 'duplicate') {
      console.log(JSON.stringify({ msg: 'duplicate skipped' }));
    }
    ch.ack(msg);
  } catch (e) {
    console.error('handler failed, requeueing:', e.message);
    try { ch.nack(msg, false, true); } catch { /* channel already closed: the broker redelivers */ }
  }
}

async function connectOnce() {
  const conn = await amqp.connect({
    protocol: 'amqp',
    hostname: process.env.RABBITMQ_HOST || 'localhost',
    port: 5672,
    username: process.env.RABBITMQ_USER || 'shop',
    password,
    heartbeat: 30,
  });
  try {
    conn.on('error', (e) => console.error('rabbitmq connection error:', e.code || e.message));
    conn.on('close', () => {
      ready = false;
      connection = null;
      channel = null;
      scheduleReconnect();
    });
    const ch = await conn.createChannel();
    ch.on('error', (e) => console.error('rabbitmq channel error:', e.code || e.message));
    ch.on('close', () => {
      ready = false;
      if (!shuttingDown) conn.close().catch(() => {});   // a dead channel means: reconnect from scratch
    });
    await ch.assertExchange(EXCHANGE, 'topic', { durable: true });
    await ch.assertQueue(QUEUE, { durable: true });
    await ch.bindQueue(QUEUE, EXCHANGE, ROUTING_KEY);
    await ch.prefetch(10);
    const { consumerTag: tag } = await ch.consume(QUEUE, (msg) => onMessage(ch, msg));
    connection = conn;
    channel = ch;
    consumerTag = tag;
    ready = true;
    console.log('consuming from', QUEUE);
  } catch (e) {
    conn.close().catch(() => {});
    throw e;
  }
}

async function start() {
  try {
    await connectOnce();
    attempt = 0;
  } catch (e) {
    console.error('rabbitmq connect failed:', e.code || e.message);
    scheduleReconnect();
  }
}

// graceful shutdown: stop being ready, stop consuming, close cleanly, then exit
async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  ready = false;
  console.log(`${signal} received, shutting down`);
  const force = setTimeout(() => process.exit(1), 15000);
  force.unref();
  try {
    if (channel && consumerTag) await channel.cancel(consumerTag);
    if (channel) await channel.close();
    if (connection) await connection.close();
  } catch { /* closing a dead connection is fine */ }
  health.close();
  process.exit(0);
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

start();
