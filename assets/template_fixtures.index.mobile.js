import { test as base } from '@mobilewright/test';
import { installTestChimp } from '@testchimp/playwright/runtime';

export const test = installTestChimp(base, { uiFixture: 'screen' });
export { expect } from '@mobilewright/test';
