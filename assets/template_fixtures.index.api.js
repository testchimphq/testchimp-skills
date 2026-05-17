import { test as base } from '@playwright/test';
import { installTestChimp } from '@testchimp/playwright/runtime';

export const test = installTestChimp(base);
export { expect } from '@playwright/test';
