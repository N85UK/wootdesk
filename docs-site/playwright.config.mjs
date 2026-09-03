import { defineConfig } from '@playwright/test';

/**
 * Accessibility checks run against the built site, not the dev server, so what
 * is tested is what would be published. A plain static server is used rather
 * than `astro preview`, which is a daemon and exits when one is already up.
 */
export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL: 'http://127.0.0.1:4321',
  },
  webServer: {
    command: 'node scripts/serve-dist.mjs',
    url: 'http://127.0.0.1:4321',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
