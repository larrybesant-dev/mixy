const fs = require('fs/promises');
const path = require('path');
const { chromium } = require('playwright');

const APP_URL = process.env.STARTUP_APP_URL || 'http://127.0.0.1:9090/';
const OUTPUT_PATH = process.env.STARTUP_LOG_PATH || 'tools/reports/startup_timeline.log';
const REPORT_PATH = process.env.STARTUP_PROBE_REPORT_PATH || 'tools/reports/startup_probe_report.json';
const CAPTURE_TIMEOUT_MS = Number(process.env.STARTUP_CAPTURE_TIMEOUT_MS || '45000');
const APP_READY_TIMEOUT_MS = Number(process.env.STARTUP_APP_READY_TIMEOUT_MS || '15000');
const APP_READY_CONTRACT_KEY = process.env.STARTUP_APP_READY_CONTRACT_KEY || 'startupAppReadyContract';
const APP_READY_CONTRACT_VERSION = 'mixvy.startup.app_ready.v1';

const REQUIRED = [
  'mainStart',
  'bindingReady',
  'firebaseReady',
  'bootstrapResolved',
  'firstFrameRendered',
];

function nowIso() {
  return new Date().toISOString();
}

function toErrorText(error) {
  if (!error) return 'unknown_error';
  if (typeof error === 'string') return error;
  if (error.message) return error.message;
  return String(error);
}

async function writeJson(filePath, data) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

async function main() {
  let browser;
  let page;

  const startedAtMs = Date.now();
  const consoleSamples = [];
  const pageErrors = [];
  const requestFailures = [];
  const responseSamples = [];
  let finalContract = null;
  let failureReason = null;
  let failureDetail = null;
  let status = 'FAIL';

  try {
    browser = await chromium.launch({ headless: true });
    page = await browser.newPage();

    page.on('console', (msg) => {
      if (consoleSamples.length < 30) {
        consoleSamples.push(`${msg.type()}: ${msg.text()}`);
      }
    });

    page.on('pageerror', (error) => {
      if (pageErrors.length < 30) {
        pageErrors.push(toErrorText(error));
      }
    });

    page.on('requestfailed', (request) => {
      if (requestFailures.length < 40) {
        requestFailures.push({
          url: request.url(),
          method: request.method(),
          errorText: request.failure() ? request.failure().errorText : 'unknown',
        });
      }
    });

    page.on('response', (response) => {
      if (responseSamples.length < 40) {
        responseSamples.push({
          url: response.url(),
          status: response.status(),
        });
      }
    });

    await page.goto(APP_URL, { waitUntil: 'domcontentloaded', timeout: CAPTURE_TIMEOUT_MS });

    try {
      await page.waitForFunction(
        ({ key, requiredCheckpoints }) => {
          const raw = window.sessionStorage.getItem(key);
          if (!raw) return false;
          let parsed;
          try {
            parsed = JSON.parse(raw);
          } catch (_) {
            return false;
          }
          if (!parsed || parsed.ready !== true || !parsed.checkpoints) return false;
          return requiredCheckpoints.every((cp) => typeof parsed.checkpoints[cp] === 'string');
        },
        { timeout: APP_READY_TIMEOUT_MS },
        { key: APP_READY_CONTRACT_KEY, requiredCheckpoints: REQUIRED },
      );
    } catch (error) {
      failureReason = 'app_contract_failure';
      failureDetail = toErrorText(error);
      throw error;
    }

    finalContract = await page.evaluate((key) => {
      const raw = window.sessionStorage.getItem(key);
      if (!raw) return null;
      try {
        return JSON.parse(raw);
      } catch (_) {
        return { malformed: true, rawSnippet: raw.slice(0, 1000) };
      }
    }, APP_READY_CONTRACT_KEY);

    if (!finalContract || finalContract.malformed) {
      failureReason = 'app_contract_failure';
      failureDetail = 'Contract missing or malformed JSON payload';
      throw new Error(failureDetail);
    }

    if (finalContract.contractVersion !== APP_READY_CONTRACT_VERSION) {
      failureReason = 'app_contract_failure';
      failureDetail = `Expected=${APP_READY_CONTRACT_VERSION} Actual=${finalContract.contractVersion || 'missing'}`;
      throw new Error(failureDetail);
    }

    if (finalContract.ready !== true) {
      failureReason = 'app_contract_failure';
      failureDetail = 'Contract ready field is not true';
      throw new Error(failureDetail);
    }

    const checkpoints = finalContract.checkpoints || {};
    const missing = REQUIRED.filter((cp) => typeof checkpoints[cp] !== 'string');
    if (missing.length > 0) {
      failureReason = 'app_contract_failure';
      failureDetail = `Missing=${missing.join(',')}`;
      throw new Error(failureDetail);
    }

    const lines = REQUIRED.map((cp) => checkpoints[cp]);
    await fs.mkdir(path.dirname(OUTPUT_PATH), { recursive: true });
    await fs.writeFile(OUTPUT_PATH, `${lines.join('\n')}\n`, 'utf8');

    status = 'PASS';
    failureReason = null;
    failureDetail = null;
  } catch (error) {
    if (!failureReason) {
      failureReason = 'probe_failure';
      failureDetail = toErrorText(error);
    }
  } finally {
    if (browser) {
      try {
        await browser.close();
      } catch (_) {
        // Ignore close failures and continue writing report.
      }
    }

    const report = {
      contractVersion: 'startup_probe_report_v1',
      generatedAtUtc: nowIso(),
      appUrl: APP_URL,
      status,
      reason: status === 'PASS' ? 'policy_rejection' : failureReason,
      detail: failureDetail,
      outputLogPath: OUTPUT_PATH,
      appReadyContractKey: APP_READY_CONTRACT_KEY,
      appReadyContractVersion: APP_READY_CONTRACT_VERSION,
      durationMs: Date.now() - startedAtMs,
      finalContract,
      evidence: {
        pageErrors,
        requestFailures,
        responseSamples,
        consoleSamples,
      },
    };

    await writeJson(REPORT_PATH, report);

    if (status !== 'PASS') {
      console.error(`Startup probe failed: ${report.reason}`);
      console.error(report.detail || 'No additional detail');
      process.exit(1);
    }

    console.log(`Captured startup timeline to ${OUTPUT_PATH}`);
    console.log(`Startup probe report written to ${REPORT_PATH}`);
  }
}

main().catch(async (error) => {
  const fallbackReport = {
    contractVersion: 'startup_probe_report_v1',
    generatedAtUtc: nowIso(),
    appUrl: APP_URL,
    status: 'FAIL',
    reason: 'probe_failure',
    detail: toErrorText(error),
  };

  try {
    await writeJson(REPORT_PATH, fallbackReport);
  } catch (_) {
    // Ignore fallback write failures.
  }

  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
