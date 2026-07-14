import { defineConfig, devices } from '@playwright/test';

/**
 * MIXVY Phase 2 Luxury Animations - Playwright Test Configuration
 * 
 * Tests validate:
 * - OnMicPanel component visibility and animations
 * - Host gold shimmer animations
 * - Speaker wine-red glow effects
 * - Spotlight ambient glow intensification
 * - Cross-browser animation consistency
 * - Performance metrics under animation load
 */

export default defineConfig({
  testDir: './tests',
  fullyParallel: false, // Run tests sequentially (important for room state)
  forbidOnly: process.env['CI'] ? true : false,
  retries: process.env['CI'] ? 2 : 0,
  workers: 1, // Single worker (Firebase auth state)
  
  reporter: [
    ['html', { outputFolder: 'test-results' }],
    ['json', { outputFile: 'test-results/test-results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
    ['list'],
  ],

  use: {
    // Base URL for all requests
    baseURL: 'https://mixvy-v2.web.app',
    
    // Trace configuration for performance analysis
    trace: 'on', // Enable tracing for all tests
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    // Action & navigation timeouts
    actionTimeout: 15000,
    navigationTimeout: 30000,
  },

  webServer: undefined, // We're testing production environment

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },

    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },

    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },

    // Mobile testing (optional)
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
  ],
});
