import http from 'node:http';
import https from 'node:https';
import { execSync } from 'node:child_process';

const URL_ENV_KEYS = [
  'PLAYWRIGHT_LIVE_URL',
  'PLAYWRIGHT_BASE_URL',
  'APP_URL',
  'STARTUP_APP_URL',
  'MIXVY_BASE_URL',
] as const;

const DEFAULT_CANDIDATE_PORTS = [
  9090, 8080, 8081, 8000, 5500, 5173, 5000, 4200, 3000,
];

function normalizeUrl(url: string): string {
  return url.endsWith('/') ? url.slice(0, -1) : url;
}

function htmlLooksLikeFlutterOrMixVy(html: string): boolean {
  const h = html.toLowerCase();
  return (
    h.includes('flutter') ||
    h.includes('flt-glass-pane') ||
    h.includes('mixvy') ||
    h.includes('main.dart.js')
  );
}

async function probeUrl(url: string, timeoutMs = 1300): Promise<boolean> {
  const protocol = url.startsWith('https') ? https : http;
  return new Promise((resolve) => {
    const req = protocol.get(url, { timeout: timeoutMs }, (res) => {
      const chunks: Buffer[] = [];
      res.on('data', (d) => chunks.push(Buffer.isBuffer(d) ? d : Buffer.from(d)));
      res.on('end', () => {
        const codeOk = (res.statusCode ?? 0) >= 200 && (res.statusCode ?? 0) < 500;
        const body = Buffer.concat(chunks).toString('utf8');
        resolve(codeOk && htmlLooksLikeFlutterOrMixVy(body));
      });
    });

    req.on('error', () => resolve(false));
    req.on('timeout', () => {
      req.destroy();
      resolve(false);
    });
  });
}

function parseListeningPortsFromNetstat(): number[] {
  try {
    const out = execSync('netstat -ano -p tcp', {
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
      windowsHide: true,
    });

    const ports = new Set<number>();
    for (const line of out.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed.includes('LISTENING')) continue;

      // Handles both IPv4 and IPv6 like:
      // TCP    127.0.0.1:5555   ... LISTENING
      // TCP    [::1]:5555       ... LISTENING
      const m = trimmed.match(/(?:\[::1\]|127\.0\.0\.1|0\.0\.0\.0):([0-9]{2,5})\s+/i);
      if (!m) continue;

      const port = Number(m[1]);
      if (Number.isInteger(port) && port > 0 && port <= 65535) {
        ports.add(port);
      }
    }

    return [...ports].sort((a, b) => a - b);
  } catch {
    return [];
  }
}

export async function detectLiveMixVyUrl(): Promise<string> {
  for (const key of URL_ENV_KEYS) {
    const value = process.env[key];
    if (!value) continue;
    const candidate = normalizeUrl(value.trim());
    if (candidate && (await probeUrl(candidate))) {
      return candidate;
    }
  }

  const netstatPorts = parseListeningPortsFromNetstat();
  const candidatePorts = [...new Set([...DEFAULT_CANDIDATE_PORTS, ...netstatPorts])];

  const hosts = ['127.0.0.1', 'localhost'];
  for (const host of hosts) {
    for (const port of candidatePorts) {
      const candidate = `http://${host}:${port}`;
      // Keep probing lightweight; skip very low system ports.
      if (port < 1000 && !DEFAULT_CANDIDATE_PORTS.includes(port)) continue;
      if (await probeUrl(candidate)) {
        return candidate;
      }
    }
  }

  throw new Error(
    'Could not auto-detect a live MixVy localhost URL. Set PLAYWRIGHT_BASE_URL to the running Flutter web URL.',
  );
}
