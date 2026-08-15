import { defineConfig, devices } from '@playwright/test';
import dotenv from 'dotenv';

/**
 * Multi-platform scaffold (web + API): setup, api, web projects.
 * Run: npx playwright test -c playwright.config.js --project web|api
 */
dotenv.config({
  path: `.env-${process.env.TESTCHIMP_ENV || 'QA'}`,
});

export default defineConfig({
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['list'],
    ['@testchimp/playwright/reporter', { verbose: false }],
  ],
  use: {
    baseURL: process.env.BASE_URL,
    actionTimeout: 15 * 1000,
    trace: 'retain-on-failure',
    screenshot: 'on',
    /* Smart-smoke defaults. Never auto-enable — set TESTCHIMP_SMART_SMOKE_ENABLED=true (or 1) per run. */
    testchimpSmartSmoke: {
      suitePercentage: 20,
      includeTags: ['smoke'],
    },
  },
  projects: [
    {
      name: 'setup',
      testDir: 'setup',
      testMatch: /global\.setup\.spec\.(js|ts)$/,
    },
    {
      name: 'api',
      dependencies: ['setup'],
      testDir: 'api',
      testMatch: '**/*.spec.{js,ts}',
      testIgnore: ['**/fixtures/**', '**/k6/**'],
    },
    {
      name: 'web',
      dependencies: ['setup'],
      testDir: 'web',
      testMatch: 'e2e/**/*.spec.{js,ts}',
      testIgnore: ['**/fixtures/**', '**/pages/**', '**/k6/**'],
      use: { ...devices['Desktop Chrome'], actionTimeout: 15 * 1000 },
    },
  ],
});
