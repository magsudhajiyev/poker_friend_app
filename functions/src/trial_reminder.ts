/**
 * Server BACKUP for the "your free trial ends tomorrow" reminder (hard
 * paywall step 4). The device schedules the real reminder and stamps
 * users/{uid}.trialReminderScheduledForMs; this only fires when the device
 * did not (app deleted, phone off, notifications blocked), so nobody gets
 * two. Pure — unit-tested in test/trial_reminder.test.js.
 */
export interface TrialUserState {
  subscriptionInTrial?: boolean;
  subscriptionWillRenew?: boolean;
  subscriptionTier?: string;
  /** subscriptionTierExpiresAt as epoch ms (the first charge). */
  expiresAtMs: number | null;
  trialReminderScheduledForMs?: number | null;
  trialReminderSentForMs?: number | null;
}

const HOUR = 60 * 60 * 1000;
/** Send window: from 24 h before the charge down to 2 h before it. */
export const REMINDER_MAX_LEAD_MS = 24 * HOUR;
export const REMINDER_MIN_LEAD_MS = 2 * HOUR;
/** Device and server read the same instant from different sources. */
const SAME_END_TOLERANCE_MS = 60 * 1000;

const sameEnd = (a: number | null | undefined, b: number): boolean =>
  typeof a === "number" && Math.abs(a - b) <= SAME_END_TOLERANCE_MS;

export function shouldSendTrialReminder(u: TrialUserState, now: number): boolean {
  if (u.subscriptionInTrial !== true || u.subscriptionWillRenew !== true) return false;
  if (u.expiresAtMs === null) return false;
  const lead = u.expiresAtMs - now;
  if (lead < REMINDER_MIN_LEAD_MS || lead > REMINDER_MAX_LEAD_MS) return false;
  if (sameEnd(u.trialReminderScheduledForMs, u.expiresAtMs)) return false; // device has it
  if (sameEnd(u.trialReminderSentForMs, u.expiresAtMs)) return false; // already sent
  return true;
}

/** English copy (the server has no price or locale for the user). */
export function trialReminderCopy(tier: string | undefined): { title: string; body: string } {
  const plan = tier === "elite" ? "Elite" : tier === "club" ? "Club" : "Pro";
  return {
    title: "Your free trial ends tomorrow",
    body: `After that, your ${plan} subscription starts. ` +
      "Cancel anytime in your subscription settings.",
  };
}
