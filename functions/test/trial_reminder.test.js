const test = require("node:test");
const assert = require("node:assert/strict");
const { shouldSendTrialReminder, trialReminderCopy } = require("../lib/trial_reminder.js");

const NOW = Date.parse("2026-10-22T12:00:00Z");
const H = 3600 * 1000;
const base = (over = {}) => ({
  subscriptionInTrial: true,
  subscriptionWillRenew: true,
  subscriptionTier: "elite",
  expiresAtMs: NOW + 20 * H,
  ...over,
});

test("renewing trial ending in 20 h, no device reminder → send", () => {
  assert.equal(shouldSendTrialReminder(base(), NOW), true);
});

test("device already scheduled it for this trial end → skip (no duplicate)", () => {
  assert.equal(shouldSendTrialReminder(base({ trialReminderScheduledForMs: NOW + 20 * H }), NOW), false);
  // Same instant read from a different source (sub-minute drift) still matches.
  assert.equal(shouldSendTrialReminder(base({ trialReminderScheduledForMs: NOW + 20 * H + 999 }), NOW), false);
});

test("device stamp for an OLD trial end does not block", () => {
  assert.equal(shouldSendTrialReminder(base({ trialReminderScheduledForMs: NOW - 30 * 24 * H }), NOW), true);
});

test("already sent for this trial end → skip", () => {
  assert.equal(shouldSendTrialReminder(base({ trialReminderSentForMs: NOW + 20 * H }), NOW), false);
});

test("outside the window: more than 24 h or less than 2 h left → skip", () => {
  assert.equal(shouldSendTrialReminder(base({ expiresAtMs: NOW + 25 * H }), NOW), false);
  assert.equal(shouldSendTrialReminder(base({ expiresAtMs: NOW + 1 * H }), NOW), false);
  assert.equal(shouldSendTrialReminder(base({ expiresAtMs: NOW + 24 * H }), NOW), true);
  assert.equal(shouldSendTrialReminder(base({ expiresAtMs: NOW + 2 * H }), NOW), true);
});

test("cancelled trial, converted (not in trial), or no expiry → skip", () => {
  assert.equal(shouldSendTrialReminder(base({ subscriptionWillRenew: false }), NOW), false);
  assert.equal(shouldSendTrialReminder(base({ subscriptionInTrial: false }), NOW), false);
  assert.equal(shouldSendTrialReminder(base({ expiresAtMs: null }), NOW), false);
});

test("copy names the plan", () => {
  assert.match(trialReminderCopy("club").body, /your Club subscription/);
  assert.match(trialReminderCopy(undefined).body, /your Pro subscription/);
  assert.equal(trialReminderCopy("elite").title, "Your free trial ends tomorrow");
});
