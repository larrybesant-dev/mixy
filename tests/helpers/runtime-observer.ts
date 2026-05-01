import type { Page, Request } from '@playwright/test';

export interface NetworkFailureEntry {
  method: string;
  url: string;
  errorText: string;
}

export interface RequestEntry {
  method: string;
  url: string;
  postDataPreview?: string;
}

export interface RuntimeSummary {
  flow: string;
  finalUrl: string;
  urlTransitions: string[];
  navigationLoopDetected: boolean;
  duplicateActions: string[];
  actionCounts: Record<string, number>;
  consoleErrors: string[];
  pageErrors: string[];
  requestFailures: NetworkFailureEntry[];
  failedSelectors: string[];
  requests: RequestEntry[];
  roomWriteSignals: number;
}

export class RuntimeObserver {
  private readonly flow: string;
  private readonly urlTransitions: string[] = [];
  private readonly consoleErrors: string[] = [];
  private readonly pageErrors: string[] = [];
  private readonly requestFailures: NetworkFailureEntry[] = [];
  private readonly requests: RequestEntry[] = [];
  private readonly failedSelectors: string[] = [];
  private readonly actionCounts = new Map<string, number>();
  private readonly duplicateActions = new Set<string>();

  constructor(flow: string) {
    this.flow = flow;
  }

  attach(page: Page): void {
    this.urlTransitions.push(page.url());

    page.on('framenavigated', (frame) => {
      if (frame !== page.mainFrame()) return;
      this.urlTransitions.push(frame.url());
    });

    page.on('console', (msg) => {
      if (msg.type() !== 'error') return;
      this.consoleErrors.push(msg.text());
    });

    page.on('pageerror', (err) => {
      this.pageErrors.push(err.stack || err.message || String(err));
    });

    page.on('requestfailed', (request) => {
      const failure = request.failure();
      this.requestFailures.push({
        method: request.method(),
        url: request.url(),
        errorText: failure?.errorText || 'unknown',
      });
    });

    page.on('request', (request: Request) => {
      const postData = request.postData();
      this.requests.push({
        method: request.method(),
        url: request.url(),
        postDataPreview:
          typeof postData === 'string' && postData.length > 0
            ? postData.slice(0, 220)
            : undefined,
      });
    });
  }

  recordAction(actionName: string): void {
    const count = (this.actionCounts.get(actionName) || 0) + 1;
    this.actionCounts.set(actionName, count);
    if (count > 1) {
      this.duplicateActions.add(actionName);
    }
  }

  recordSelectorFailure(selectorOrAction: string, reason: string): void {
    this.failedSelectors.push(`${selectorOrAction} :: ${reason}`);
  }

  countTransitionsMatching(pattern: RegExp): number {
    return this.urlTransitions.filter((url) => pattern.test(url)).length;
  }

  countRoomWriteSignals(): number {
    return this.requests.filter((r) => {
      const u = r.url.toLowerCase();
      const body = (r.postDataPreview || '').toLowerCase();
      return (
        /documents\/rooms/.test(u) ||
        u.includes('documents:commit') ||
        body.includes('"rooms"') ||
        body.includes('/rooms/')
      );
    }).length;
  }

  private detectNavigationLoop(): boolean {
    const cleaned = this.urlTransitions.filter(Boolean);
    if (cleaned.length < 6) return false;

    const tail = cleaned.slice(-10);

    // Detect A-B-A-B style loop in the tail.
    for (let i = 0; i + 3 < tail.length; i += 1) {
      const a = tail[i];
      const b = tail[i + 1];
      const c = tail[i + 2];
      const d = tail[i + 3];
      if (a === c && b === d && a !== b) {
        return true;
      }
    }

    // Detect same URL repeated too many times.
    const counts = new Map<string, number>();
    for (const u of cleaned) {
      counts.set(u, (counts.get(u) || 0) + 1);
      if ((counts.get(u) || 0) >= 6) {
        return true;
      }
    }

    return false;
  }

  summary(finalUrl: string): RuntimeSummary {
    return {
      flow: this.flow,
      finalUrl,
      urlTransitions: this.urlTransitions,
      navigationLoopDetected: this.detectNavigationLoop(),
      duplicateActions: [...this.duplicateActions],
      actionCounts: Object.fromEntries(this.actionCounts.entries()),
      consoleErrors: this.consoleErrors,
      pageErrors: this.pageErrors,
      requestFailures: this.requestFailures,
      failedSelectors: this.failedSelectors,
      requests: this.requests,
      roomWriteSignals: this.countRoomWriteSignals(),
    };
  }
}
