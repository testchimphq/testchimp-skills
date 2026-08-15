import { sleep } from 'k6';

/**
 * Pause so each VU models a concurrent *user* on the journey, not a tight
 * request loop. Smoke skips (1 iteration). Load/volume default 1s / 0.5s.
 * Override with K6_THINK_TIME_SEC (0 disables).
 *
 * Call between user-visible steps and once at the end of `default`.
 */
export function thinkTime() {
  const profile = __ENV.K6_PROFILE || 'smoke';
  if (profile === 'smoke') return;
  const raw = Number(__ENV.K6_THINK_TIME_SEC);
  const fallback = profile === 'volume' ? 0.5 : 1;
  const seconds = Number.isFinite(raw) && raw >= 0 ? raw : fallback;
  if (seconds > 0) sleep(seconds);
}
