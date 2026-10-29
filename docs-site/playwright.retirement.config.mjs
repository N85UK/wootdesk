import { defineConfig } from '@playwright/test';

const run = process.env.WOOTDESK_A11Y_RUN ??= Date.now() + '-' + process.pid;
export default defineConfig({
  testDir: './tests', testMatch: 'retirement-accessibility.spec.mjs',
  fullyParallel: false, workers: 1, retries: 0, forbidOnly: true,
  outputDir: '.retirement-evidence/a11y-' + run,
  reporter: 'list',
  use: { baseURL: 'http://127.0.0.1:4337' },
  webServer: { command: 'node scripts/serve-retirement.mjs', url: 'http://127.0.0.1:4337/build-info.json',
    reuseExistingServer: false, gracefulShutdown: { signal: 'SIGTERM', timeout: 5000 } },
});
