#!/usr/bin/env node
/**
 * Schedule a Daily Challenge day: writes authored_days/{yyyy-MM-dd} =
 * {hands: [tree ids]} (play order, max 5). Every id must already exist in
 * authored_spots (upload trees first with build_tree.js --upload).
 *
 *   node schedule_day.js --day 2026-10-22 --hands id1,id2,id3,id4,id5
 *   node schedule_day.js --day 2026-10-22 --show      # print the day
 *   node schedule_day.js --day 2026-10-22 --clear     # unschedule (RNG day)
 *
 * The day key is the player's LOCAL date (the app uses its local calendar).
 */
const path = require('path');

function arg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return def;
  const v = process.argv[i + 1];
  return v === undefined || v.startsWith('--') ? true : v;
}

const DAY = arg('day');
const HANDS = arg('hands');
const SHOW = arg('show', false);
const CLEAR = arg('clear', false);
const MAX_HANDS = 5;

async function main() {
  if (typeof DAY !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(DAY)) {
    throw new Error('--day yyyy-MM-dd is required');
  }
  const admin = require('firebase-admin');
  admin.initializeApp({
    credential: admin.credential.cert(
      require(path.join(__dirname, 'service-account.json'))
    ),
  });
  const db = admin.firestore();
  const ref = db.collection('authored_days').doc(DAY);

  if (SHOW) {
    const snap = await ref.get();
    console.log(snap.exists ? JSON.stringify(snap.data()) : `${DAY}: not scheduled`);
    return;
  }
  if (CLEAR) {
    await ref.delete();
    console.log(`Cleared authored_days/${DAY} (plays the RNG challenge)`);
    return;
  }
  if (typeof HANDS !== 'string') throw new Error('--hands id1,id2,... is required');
  const ids = HANDS.split(',').map((s) => s.trim()).filter(Boolean);
  if (ids.length === 0 || ids.length > MAX_HANDS) {
    throw new Error(`--hands needs 1..${MAX_HANDS} tree ids (got ${ids.length})`);
  }
  for (const id of ids) {
    const spot = await db.collection('authored_spots').doc(id).get();
    if (!spot.exists) throw new Error(`authored_spots/${id} does not exist — upload it first`);
  }
  await ref.set({ hands: ids, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  console.log(`Scheduled authored_days/${DAY}: ${ids.join(', ')}`);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
