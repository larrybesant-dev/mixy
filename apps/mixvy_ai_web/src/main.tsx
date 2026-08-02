import {StrictMode} from 'react';
// @ts-ignore react-dom types missing in AI Studio
import {createRoot} from 'react-dom/client';
import App from './App.tsx';
import { ErrorBoundary } from './components/ErrorBoundary.tsx';
import './index.css';

function ensureMountNode(): HTMLElement {
  const existing = document.getElementById('root');
  if (existing) {
    return existing;
  }

  // AI Studio preview can occasionally boot with a partial DOM; create a fallback mount.
  const fallback = document.createElement('div');
  fallback.id = 'root';
  document.body.appendChild(fallback);
  console.error('[bootstrap] Missing #root mount node. Created fallback mount node.');
  return fallback;
}

function renderBootstrapError(err: unknown) {
  const message = err instanceof Error ? err.message : String(err);
  const pre = document.createElement('pre');
  pre.style.whiteSpace = 'pre-wrap';
  pre.style.padding = '16px';
  pre.style.color = '#f7ede2';
  pre.style.background = '#781e2b';
  pre.style.fontFamily = 'monospace';
  pre.textContent = `App bootstrap failed: ${message}`;
  document.body.innerHTML = '';
  document.body.appendChild(pre);
}

try {
  const mountNode = ensureMountNode();
  createRoot(mountNode).render(
    <StrictMode>
      <ErrorBoundary>
        <App />
      </ErrorBoundary>
    </StrictMode>,
  );
} catch (err) {
  console.error('[bootstrap] Failed to mount app:', err);
  renderBootstrapError(err);
}

