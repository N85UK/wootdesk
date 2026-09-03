import { defineConfig } from '@playwright/test';

/**
 * Accessibility checks run against the built site, not the dev server, so what
 * is tested is what would be published. A plain static server is used rather
 * than `astro preview`, which is a daemon and exits when one is already up.
 */
// Point SITE_URL at a deployed site to run these checks against it. The local
// static server does not apply the _headers file, so a content security policy
// can only be proven against a real deployment: passing locally says nothing
// about whether the CSP breaks search or styling in production.
const siteURL = process.env.SITE_URL ?? 'http://127.0.0.1:4321';
const useLocalServer = !process.env.SITE_URL;

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL: siteURL,
  },
  webServer: useLocalServer ? {
    command: 'node scripts/serve-dist.mjs',
    url: 'http://127.0.0.1:4321',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  } : undefined,
});
