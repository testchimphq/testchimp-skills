import { defineConfig, type MobilewrightConfig } from 'mobilewright';
import dotenv from 'dotenv';

/**
 * Multi-platform scaffold (native): same project matrix as template_mobile_mobilewright.config.ts
 * with testIgnore including web/. Requires mobilewright >= 0.0.37 (per-project installApps).
 */
dotenv.config({
  path: `.env-${process.env.TESTCHIMP_ENV || 'QA'}`,
});

const useMobileUse = Boolean(process.env['MOBILE_USE_API_KEY']);

const config: MobilewrightConfig = {
  testDir: '.',
  retries: 0,
  timeout: 120_000,
  bundleId: '[ENTER_IOS_BUNDLE_ID]',
  fullyParallel: true,
  workers: process.env.CI ? 2 : 1,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'mobilewright-report' }],
    ['@testchimp/playwright/reporter', { verbose: false }],
  ],
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
      testIgnore: ['**/fixtures/**', 'web/**'],
    },
    // @testchimp-scaffold:ios-project
    {
      name: 'ios',
      dependencies: ['setup'],
      testDir: 'mobile',
      testMatch: ['e2e/common/**/*.spec.{js,ts}', 'e2e/ios/**/*.spec.{js,ts}'],
      testIgnore: ['**/fixtures/**', '**/pages/**', '**/shared/**', 'web/**'],
      use: {
        platform: 'ios',
        bundleId: '[ENTER_IOS_BUNDLE_ID]',
        installApps: '[PATH_TO_IOS_APP]',
        actionTimeout: 15 * 1000,
      },
    },
    // @testchimp-scaffold:/ios-project
    // @testchimp-scaffold:android-project
    {
      name: 'android',
      dependencies: ['setup'],
      testDir: 'mobile',
      testMatch: ['e2e/common/**/*.spec.{js,ts}', 'e2e/android/**/*.spec.{js,ts}'],
      testIgnore: ['**/fixtures/**', '**/pages/**', '**/shared/**', 'web/**'],
      use: {
        platform: 'android',
        bundleId: '[ENTER_ANDROID_BUNDLE_ID]',
        installApps: '[PATH_TO_APK]',
        actionTimeout: 15 * 1000,
      },
    },
    // @testchimp-scaffold:/android-project
  ],
};

if (useMobileUse) {
  config.driver = {
    type: 'mobile-use',
    apiKey: process.env['MOBILE_USE_API_KEY'],
  };
}

export default defineConfig(config);
