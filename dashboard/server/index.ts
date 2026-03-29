import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from '@aws-sdk/client-s3';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ── Configuration ───────────────────────────────────────────
const PORT = process.env.PORT || 3000;
const AGENT_HOSTS = [
  process.env.AGENT_1_HOST || 'agent-1',
  process.env.AGENT_2_HOST || 'agent-2',
  process.env.AGENT_3_HOST || 'agent-3',
  process.env.AGENT_4_HOST || 'agent-4',
  process.env.AGENT_5_HOST || 'agent-5',
].filter((_, i) => {
  // Only include agents that have a host configured or use defaults for the first 5
  const envKey = `AGENT_${i + 1}_HOST`;
  return process.env[envKey] || i < 5;
});
const AGENT_STATUS_PORT = process.env.AGENT_STATUS_PORT || '8080';
const BASIC_AUTH_USER = process.env.DASHBOARD_USER || 'admin';
const BASIC_AUTH_PASS = process.env.DASHBOARD_PASSWORD || '';

// ── S3 / Bucket Configuration ───────────────────────────────
const BUCKET_ENDPOINT = process.env.BUCKET_ENDPOINT || '';
const BUCKET_ACCESS_KEY_ID = process.env.BUCKET_ACCESS_KEY_ID || '';
const BUCKET_SECRET_ACCESS_KEY = process.env.BUCKET_SECRET_ACCESS_KEY || '';
const BUCKET_NAME = process.env.BUCKET_NAME || '';
const BUCKET_REGION = process.env.BUCKET_REGION || 'ams';

const SESSIONS_KEY = 'sessions/history.json';

const bucketConfigured =
  BUCKET_ENDPOINT &&
  BUCKET_ACCESS_KEY_ID &&
  BUCKET_SECRET_ACCESS_KEY &&
  BUCKET_NAME;

let s3Client: S3Client | null = null;

if (bucketConfigured) {
  s3Client = new S3Client({
    endpoint: BUCKET_ENDPOINT,
    region: BUCKET_REGION,
    credentials: {
      accessKeyId: BUCKET_ACCESS_KEY_ID,
      secretAccessKey: BUCKET_SECRET_ACCESS_KEY,
    },
    forcePathStyle: true, // Required for Railway Buckets / MinIO
  });
  console.log(
    `Bucket storage enabled: ${BUCKET_NAME} (${BUCKET_REGION})`
  );
} else {
  console.log(
    'Bucket storage not configured, using in-memory session history'
  );
}

// ── Types ───────────────────────────────────────────────────

interface SessionTokens {
  input: number;
  output: number;
  reasoning: number;
}

interface SessionModel {
  id: string;
  provider: string;
  messages: number;
}

interface AgentStatus {
  id: string;
  status: 'idle' | 'active' | 'busy' | 'offline';
  repo: string | null;
  session: {
    id: string | null;
    title: string | null;
    duration: string | null;
    messageCount: number;
    tokens?: SessionTokens;
    cost?: number;
    models?: SessionModel[];
  };
  resources: {
    cpu: number;
    memory: number;
  };
  uptime: string;
}

interface SessionHistoryItem {
  id: string;
  agentId: string;
  title: string;
  duration: string;
  status: 'completed' | 'aborted' | 'active';
  completedAt: string;
  tokens?: SessionTokens;
  cost?: number;
  models?: SessionModel[];
}

// ── Session History Persistence ─────────────────────────────

let sessionHistory: SessionHistoryItem[] = [];
let sessionsDirty = false;
let lastBucketWrite = 0;
const BUCKET_WRITE_DEBOUNCE = 10_000; // 10 seconds

async function loadSessionsFromBucket(): Promise<void> {
  if (!s3Client || !bucketConfigured) return;

  try {
    const command = new GetObjectCommand({
      Bucket: BUCKET_NAME,
      Key: SESSIONS_KEY,
    });
    const response = await s3Client.send(command);
    const body = await response.Body?.transformToString();
    if (body) {
      sessionHistory = JSON.parse(body);

      // Mark any stale 'active' sessions as 'completed' (dashboard restarted)
      for (const session of sessionHistory) {
        if (session.status === 'active') {
          session.status = 'completed';
          session.completedAt = 'before restart';
        }
      }

      console.log(
        `Loaded ${sessionHistory.length} sessions from bucket`
      );
    }
  } catch (error: unknown) {
    const err = error as { name?: string };
    if (err.name === 'NoSuchKey') {
      console.log('No session history found in bucket, starting fresh');
    } else {
      console.error('Failed to load sessions from bucket:', error);
    }
  }
}

async function saveSessionsToBucket(): Promise<void> {
  if (!s3Client || !bucketConfigured || !sessionsDirty) return;

  const now = Date.now();
  if (now - lastBucketWrite < BUCKET_WRITE_DEBOUNCE) return;

  try {
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: SESSIONS_KEY,
      Body: JSON.stringify(sessionHistory, null, 2),
      ContentType: 'application/json',
    });
    await s3Client.send(command);
    lastBucketWrite = now;
    sessionsDirty = false;
  } catch (error) {
    console.error('Failed to save sessions to bucket:', error);
  }
}

// ── Agent Status Fetching ───────────────────────────────────

async function fetchAgentStatus(
  host: string,
  index: number
): Promise<AgentStatus> {
  const agentId = `agent-${index + 1}`;
  const timeout = 5000;

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    const response = await fetch(
      `http://${host}:${AGENT_STATUS_PORT}/status`,
      { signal: controller.signal }
    );

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();
    return {
      ...data,
      id: agentId,
    };
  } catch {
    return {
      id: agentId,
      status: 'offline',
      repo: null,
      session: {
        id: null,
        title: null,
        duration: null,
        messageCount: 0,
        tokens: { input: 0, output: 0, reasoning: 0 },
        cost: 0,
        models: [],
      },
      resources: { cpu: 0, memory: 0 },
      uptime: 'N/A',
    };
  }
}

async function fetchAllAgentStatuses(): Promise<AgentStatus[]> {
  const statuses = await Promise.all(
    AGENT_HOSTS.map((host, index) => fetchAgentStatus(host, index))
  );

  // Track session history
  for (const status of statuses) {
    // Check if there's an active session for this agent that needs completing
    const existingSession = sessionHistory.find(
      (s) => s.agentId === status.id && s.status === 'active'
    );

    // If agent went idle/offline and we have an active session, mark it completed
    if (existingSession && (status.status === 'idle' || status.status === 'offline' || !status.session.title)) {
      existingSession.status = 'completed';
      existingSession.completedAt = 'just now';
      sessionsDirty = true;
      continue;
    }

    // If agent has an active session with a title
    if (status.session.title && status.status !== 'offline' && status.status !== 'idle') {
      if (!existingSession) {
        // New active session
        sessionHistory.unshift({
          id: status.session.id || `${status.id}-${Date.now()}`,
          agentId: status.id,
          title: status.session.title,
          duration: status.session.duration || '0m',
          status: 'active',
          completedAt: 'now',
          tokens: status.session.tokens,
          cost: status.session.cost,
          models: status.session.models,
        });
        sessionsDirty = true;
      } else {
        // Update active session with latest data
        existingSession.title =
          status.session.title || existingSession.title;
        existingSession.duration =
          status.session.duration || existingSession.duration;

        // Only update tokens/cost if the new values are higher (never go backwards)
        const newCost = status.session.cost ?? 0;
        if (newCost > (existingSession.cost ?? 0)) {
          existingSession.tokens = status.session.tokens;
          existingSession.cost = newCost;
          existingSession.models = status.session.models;
        }
      }
    }
  }

  // Keep only last 50 sessions
  if (sessionHistory.length > 50) {
    sessionHistory.length = 50;
  }

  // Persist to bucket (debounced)
  saveSessionsToBucket().catch(() => {});

  return statuses;
}

// ── Authentication ──────────────────────────────────────────

function checkAuth(req: http.IncomingMessage): boolean {
  if (!BASIC_AUTH_PASS) return true;

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Basic ')) {
    return false;
  }

  const base64Credentials = authHeader.slice(6);
  const credentials = Buffer.from(base64Credentials, 'base64').toString(
    'utf-8'
  );
  const [username, password] = credentials.split(':');

  return username === BASIC_AUTH_USER && password === BASIC_AUTH_PASS;
}

// ── Static File Serving ─────────────────────────────────────

const mimeTypes: Record<string, string> = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

function serveStatic(
  req: http.IncomingMessage,
  res: http.ServerResponse,
  urlPath: string
): boolean {
  const distPath = path.join(__dirname, '../dist');
  let filePath = path.join(
    distPath,
    urlPath === '/' ? 'index.html' : urlPath
  );

  if (!filePath.startsWith(distPath)) {
    return false;
  }

  if (!fs.existsSync(filePath)) {
    filePath = path.join(distPath, 'index.html');
    if (!fs.existsSync(filePath)) {
      return false;
    }
  }

  const stat = fs.statSync(filePath);
  if (stat.isDirectory()) {
    filePath = path.join(filePath, 'index.html');
    if (!fs.existsSync(filePath)) {
      return false;
    }
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = mimeTypes[ext] || 'application/octet-stream';

  res.writeHead(200, { 'Content-Type': contentType });
  fs.createReadStream(filePath).pipe(res);
  return true;
}

// ── HTTP Server ─────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://${req.headers.host}`);
  const pathname = url.pathname;

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization'
  );

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Check authentication
  if (!checkAuth(req)) {
    res.setHeader(
      'WWW-Authenticate',
      'Basic realm="OpenCode Dashboard"'
    );
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Unauthorized' }));
    return;
  }

  // API routes
  if (pathname === '/api/agents') {
    try {
      const agents = await fetchAllAgentStatuses();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(agents));
    } catch {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({ error: 'Failed to fetch agent statuses' })
      );
    }
    return;
  }

  if (pathname === '/api/sessions') {
    // Only return completed sessions (active ones are shown in the agent detail view)
    const completedSessions = sessionHistory.filter(
      (s) => s.status !== 'active'
    );
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(completedSessions.slice(0, 20)));
    return;
  }

  if (pathname === '/api/health') {
    // Parse bastion host from VITE_BASTION_HOST (format: "hostname:port")
    const bastionHostEnv = process.env.VITE_BASTION_HOST || '';
    const [bastionHost, bastionPortStr] = bastionHostEnv.split(':');
    const bastionPort = parseInt(bastionPortStr, 10) || 0;

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        status: 'ok',
        timestamp: new Date().toISOString(),
        bucketEnabled: !!bucketConfigured,
        bastion: bastionHost
          ? { host: bastionHost, port: bastionPort, user: 'opencode' }
          : undefined,
      })
    );
    return;
  }

  // Serve static files
  if (serveStatic(req, res, pathname)) {
    return;
  }

  // 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

// ── Startup ─────────────────────────────────────────────────

async function start() {
  // Load session history from bucket on startup
  await loadSessionsFromBucket();

  server.listen(PORT, () => {
    console.log(`Dashboard server running on http://localhost:${PORT}`);
    console.log(`Monitoring agents: ${AGENT_HOSTS.join(', ')}`);
    if (BASIC_AUTH_PASS) {
      console.log(`Authentication enabled (user: ${BASIC_AUTH_USER})`);
    } else {
      console.log(
        'Warning: No DASHBOARD_PASSWORD set, authentication disabled'
      );
    }
  });
}

start().catch((error) => {
  console.error('Failed to start dashboard server:', error);
  process.exit(1);
});
