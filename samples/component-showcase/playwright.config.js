// @ts-check
const { defineConfig, devices } = require('@playwright/test');

/**
 * Playwright configuration for Zylix Component Showcase tests.
 * Tests v0.7.0 Component Library features.
 * @see https://playwright.dev/docs/test-configuration
 */
module.exports = defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'list',

  // Visual comparison settings
  snapshotDir: './tests/snapshots',
  snapshotPathTemplate: '{snapshotDir}/{testFilePath}/{arg}{ext}',

  // Expect settings for visual comparisons
  expect: {
    toHaveScreenshot: {
      // Allow small differences for anti-aliasing
      threshold: 0.2,
      // Maximum allowed ratio of different pixels
      maxDiffPixelRatio: 0.05,
    },
  },

  use: {
    baseURL: 'http://localhost:8081',
    trace: 'on-first-retry',
    // Screenshot settings
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // Start local server before tests
  webServer: {
    command: 'python3 -m http.server 8081',
    url: 'http://localhost:8081',
    reuseExistingServer: !process.env.CI,
    timeout: 30000,
  },
});
