import { defineConfig, devices } from '@playwright/test';
import dotenv from 'dotenv';

/**
SETUP INSTRUCTIONS FOR CI:
1) run `npm install playwright-testchimp` in your repo.
2) Ensure TESTCHIMP_API_KEY is set in CI (from Project Settings → Key management). TESTCHIMP_PROJECT_ID is optional.
3) Sync this 'tests' folder to a folder in your repo (Click "Sync with GitHub" - in SmartTests page in TestChimp).
4) Setup your git workflow to run tests using standard playwright runner. Sample workflow file: https://github.com/testchimphq/CafeTime/blob/main/.github/workflows/playwright-tests.yml

Note: the runner should be run from the tests folder to ensure proper path resolution (refer sample workflow file).
Full Documentation: https://docs.testchimp.io/smart-tests/run-in-ci-playwright

Keep @playwright/test and playwright on the SAME version in package.json (e.g. both 1.59.x). Mismatched versions cause
"Playwright Test did not expect test() to be called here". Verify with: npm ls @playwright/test playwright
If a dependency nests another playwright, use package.json "overrides" to force a single version.

Global setup: project "setup" runs first (tests/setup/global.setup.spec.js), then "chromium" discovers *.spec.js / *.test.js (and .ts) anywhere under tests/ except setup/. See https://playwright.dev/docs/test-global-setup-teardown#option-1-project-dependencies
**/

dotenv.config({
  path: `.env-${process.env.TESTCHIMP_ENV || 'QA'}`
});

/**
 * See https://playwright.dev/docs/test-configuration.
 * Config file lives in tests/; testDir values are relative to this file.
 */
export default defineConfig({
  /* Run tests in files in parallel */
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,
  /* Opt out of parallel tests on CI. */
  workers: process.env.CI ? 1 : undefined,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: [
    ['list'],
    ['playwright-testchimp/reporter', {
      verbose: false
    }]
  ],
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    baseURL:process.env.BASE_URL,
    /* Per-step locator/API wait; without this, Playwright uses the test timeout for each action.
     * Existing projects may omit this in Git; TestChimp platform runs still inject the same default
     * (15s) into playwright.config when materializing the workspace before `playwright test`. */
    actionTimeout: 15 * 1000,
    /* Record trace each run; discard if the test passes (valid TraceMode — not `on-failure`, which Playwright rejects). See https://playwright.dev/docs/trace-viewer */
    trace: 'retain-on-failure',
    /* Capture screenshots when tests fail */
    screenshot: 'on',
  },

  projects: [
    {
      name: 'setup',
      testDir: 'setup',
      testMatch: /global\.setup\.spec\.(js|ts)$/,
    },
    {
      name: 'chromium',
      dependencies: ['setup'],
      testDir: '.',
      testIgnore: ['**/setup/**'],
      testMatch: '**/*.{spec,test}.{js,ts}',
      use: { ...devices['Desktop Chrome'], actionTimeout: 15 * 1000 },
    },
  ],
});
