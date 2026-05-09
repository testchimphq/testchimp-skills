import { defineConfig, type MobilewrightConfig } from 'mobilewright';
import dotenv from 'dotenv';

/**
SETUP INSTRUCTIONS FOR CI:
1) run `npm install @testchimp/playwright` in your repo.
2) Ensure TESTCHIMP_API_KEY is set in CI (from Project Settings → Key management). TESTCHIMP_PROJECT_ID is optional.
3) Sync this 'tests' folder to a folder in your repo (Click "Sync with GitHub" - in SmartTests page in TestChimp).
4) Setup your git workflow to run tests using standard playwright runner. Sample workflow file: https://github.com/testchimphq/CafeTime/blob/main/.github/workflows/playwright-tests.yml

Note: the runner should be run from the tests folder to ensure proper path resolution (refer sample workflow file).
Full Documentation: https://docs.testchimp.io/smart-tests/run-in-ci-playwright

Keep @mobilewright/test and mobilewright on the SAME version in package.json. Mismatched versions cause
"Playwright Test did not expect test() to be called here". Verify with: npm ls @mobilewright/test mobilewright
If a dependency nests another playwright, use package.json "overrides" to force a single version.

Global setup: project "setup" runs first (tests/setup/global.setup.spec.js), then "mobile" discovers *.spec.js / *.test.js (and .ts) anywhere under tests/ except setup/. See https://playwright.dev/docs/test-global-setup-teardown#option-1-project-dependencies
**/

dotenv.config({
  path: `.env-${process.env.TESTCHIMP_ENV || 'QA'}`
});

// Cloud (mobile-use) needs a device .ipa; local simulators need a Debug-iphonesimulator .app
// (`make ipa` vs `make build` from the repo root — see Makefile).
const useMobileUse = Boolean(process.env['MOBILE_USE_API_KEY']);

const config: MobilewrightConfig = {
  // tests are in the current directory
  testDir: '.',

  // if a test fails, don't try it again
  retries: 0,

  // extra headroom for fixture teardown
  timeout: 120_000,

  // platform is required
  platform: 'ios',

  // bundle identifier of our app under test
  bundleId: '[ENTER_BUNDLE_ID]',

  // enable paralllelism on all tests, not just their files
  fullyParallel: true,

  // how many workers (devices) at the same time?
  workers: process.env.CI ? 2 : 1,

  // install this app before starting
  installApps: '[PATH_TO_IPA]',

  reporter: [
    ['list'],
    ['html', { outputFolder: 'mobilewright-report' }],
    [
      '@testchimp/playwright/reporter',
      {
        verbose: false,
      },
    ],
  ],

    projects: [
      {
        name: 'setup',
        testDir: 'setup',
        testMatch: /global\.setup\.spec\.(js|ts)$/,
      },
      {
        name: 'mobile',
        dependencies: ['setup'],
        testDir: '.',
        testIgnore: ['**/setup/**'],
        testMatch: '**/*.{spec,test}.{js,ts}',
        use: { actionTimeout: 15 * 1000 },
      },
    ],
};

// if environmet exists, we'll use mobile-use driver and allocate a device on the cloud
// otherwise we run it on a device locally with mobilecli
if (useMobileUse) {
  config.driver = {
    type: 'mobile-use',
    apiKey: process.env['MOBILE_USE_API_KEY'],
  };
}

export default defineConfig(config);
