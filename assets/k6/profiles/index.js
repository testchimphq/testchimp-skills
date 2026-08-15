import { smokeOptions } from './smoke.js';
import { loadOptions } from './load.js';
import { volumeOptions } from './volume.js';

const profiles = { smoke: smokeOptions, load: loadOptions, volume: volumeOptions };
const requested = __ENV.K6_PROFILE || 'smoke';

if (!profiles[requested]) {
  throw new Error(`Unknown K6_PROFILE "${requested}"; use smoke, load, or volume`);
}

export const profileName = requested;
export const profileOptions = profiles[requested];
