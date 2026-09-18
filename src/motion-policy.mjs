/** Pure scheduling policy: one scene owns the animation slot at a time. */
export function createPetScheduler({
  calmMs = 45000,
  actionMs = 7200,
  initialDelayMs = 10000,
} = {}) {
  let nextAt = initialDelayMs;
  let active = null;
  const completed = new Set();
  return {
    tick(now, eligible = [], paused = false) {
      if (paused) {
        active = null;
        nextAt = now + calmMs;
        return null;
      }
      if (active && (now >= active.until || !eligible.includes(active.id))) {
        completed.add(active.id);
        active = null;
        nextAt = now + calmMs;
      }
      if (active) return active;
      if (now < nextAt) return null;
      const id = eligible.find((item) => !completed.has(item));
      if (!id) return null;
      active = { id, startedAt: now, until: now + actionMs };
      return active;
    },
    defer(now) {
      active = null;
      nextAt = now + calmMs;
    },
  };
}
export function canAdvanceLocale(
  { now, lastChange, pausedUntil, visible, hidden, reduced, paused, focused },
  interval = 8000,
) {
  return (
    visible &&
    !hidden &&
    !reduced &&
    !paused &&
    !focused &&
    now >= pausedUntil &&
    now - lastChange >= interval
  );
}
