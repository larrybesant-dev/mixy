import { Page, TestInfo } from '@playwright/test';

const DEFAULT_LATENCY_MS = 600;

export interface NetworkDiagnostics {
  delayedRequests: string[];
  failedRequests: string[];
  pageErrors: string[];
  consoleErrors: string[];
}

function isBackendRequest(rawUrl: string): boolean {
  try {
    const hostname = new URL(rawUrl).hostname.toLowerCase();
    return hostname.endsWith('googleapis.com') ||
      hostname.endsWith('firebaseio.com') ||
      hostname.endsWith('cloudfunctions.net');
  } catch {
    return false;
  }
}

export async function simulateBackendLatency(
  page: Page,
  latencyMs = Number(process.env.E2E_LATENCY_MS ?? DEFAULT_LATENCY_MS),
): Promise<NetworkDiagnostics> {
  const diagnostics: NetworkDiagnostics = {
    delayedRequests: [],
    failedRequests: [],
    pageErrors: [],
    consoleErrors: [],
  };

  page.on('requestfailed', (request) => {
    diagnostics.failedRequests.push(
      `${request.method()} ${request.url()} (${request.failure()?.errorText ?? 'unknown failure'})`,
    );
  });
  page.on('pageerror', (error) => diagnostics.pageErrors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') {
      diagnostics.consoleErrors.push(message.text());
    }
  });

  await page.route('**/*', async (route) => {
    const request = route.request();
    if (isBackendRequest(request.url())) {
      diagnostics.delayedRequests.push(`${request.method()} ${request.url()}`);
      await new Promise((resolve) => setTimeout(resolve, latencyMs));
    }
    await route.continue();
  });

  return diagnostics;
}

export async function attachNetworkDiagnostics(
  testInfo: TestInfo,
  diagnostics: NetworkDiagnostics,
): Promise<void> {
  await testInfo.attach('network-diagnostics.json', {
    body: Buffer.from(JSON.stringify(diagnostics, null, 2)),
    contentType: 'application/json',
  });
}