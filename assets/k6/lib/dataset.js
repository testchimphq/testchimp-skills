import { fail } from 'k6';
import { SharedArray } from 'k6/data';
import { pickSteppedVolumeTenant, recordVolumeSize } from './volume-size.js';

/**
 * Identity pool for load (one tenant per VU) and volume staircases (one
 * tenant per cardinality hold). SEED_COMMAND writes PERF_TENANTS_FILE.
 * Volume tenants MUST include numeric `volumeSize` — Executions charts that
 * gauge instead of VUs.
 */
const tenants = new SharedArray('perf-tenants', () => {
  const path = __ENV.PERF_TENANTS_FILE;
  if (!path) {
    return [];
  }
  try {
    const data = JSON.parse(open(path));
    if (Array.isArray(data)) return data;
    if (Array.isArray(data.tenants)) return data.tenants;
    return [];
  } catch (e) {
    return [];
  }
});

function envFallbackTenant() {
  const tenant = {
    apiKey: __ENV.PERF_API_KEY || __ENV.API_KEY || '',
    baseUrl: __ENV.BASE_URL || __ENV.BACKEND_URL || '',
    orgId: __ENV.PERF_LOCAL_ORG_ID || __ENV.ORG_ID || '',
    projectId: __ENV.PERF_LOCAL_PROJECT_ID || __ENV.PROJECT_ID || '',
    userId: __ENV.PERF_LOCAL_USER_ID || '',
  };
  const n = Number(__ENV.K6_VOLUME_SIZE || '');
  if (__ENV.K6_VOLUME_SIZE && Number.isFinite(n) && n >= 0) {
    tenant.volumeSize = n;
  }
  return tenant;
}

export function pickTenant() {
  const profile = __ENV.K6_PROFILE || 'smoke';
  if (!tenants.length) {
    const fallback = envFallbackTenant();
    if (profile === 'volume') recordVolumeSize(fallback.volumeSize);
    return fallback;
  }
  if (profile === 'volume') {
    const stepped = pickSteppedVolumeTenant(tenants);
    if (!stepped) {
      fail(
        'volume profile requires numeric volumeSize on seeded tenants (run-volume-staircase.sh seed contract). Do not emit volume_size from K6_VOLUME_STEPS against one unchanged dataset.'
      );
    }
    recordVolumeSize(stepped.volumeSize);
    return stepped;
  }
  const vu = typeof __VU === 'number' && __VU > 0 ? __VU : 1;
  return tenants[(vu - 1) % tenants.length];
}

export function isSmoke() {
  return (__ENV.K6_PROFILE || 'smoke') === 'smoke';
}
