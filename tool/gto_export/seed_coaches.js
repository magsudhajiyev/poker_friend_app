#!/usr/bin/env node
// Seed the three coach persona files into Firestore `coaches/{coachKey}`.
//
// The repo JSON (coaches/{duke,vega,nova}.json) is the SOURCE OF TRUTH; this
// pushes them to Firestore so they can be hot-edited in the console without an
// app release. Re-run after editing a persona file.
//
//   node seed_coaches.js          # write all three
//   node seed_coaches.js --show   # print what's in Firestore, write nothing
//
// Admin SDK creds: ./service-account.json (gitignored).
'use strict';

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const SHOW = process.argv.includes('--show');
const COACHES_DIR = path.join(__dirname, '..', '..', 'coaches');
const FILES = ['duke.json', 'vega.json', 'nova.json'];

function initAdmin() {
  const keyFile = path.join(__dirname, 'service-account.json');
  if (!fs.existsSync(keyFile)) {
    console.error('Missing service-account.json in tool/gto_export/.');
    process.exit(1);
  }
  admin.initializeApp({ credential: admin.credential.cert(require(keyFile)) });
  return admin.firestore();
}

async function main() {
  const db = initAdmin();

  if (SHOW) {
    const snap = await db.collection('coaches').get();
    if (snap.empty) {
      console.log('coaches/ is empty.');
    } else {
      snap.forEach((d) => {
        const c = d.data();
        console.log(
          `${d.id.padEnd(10)} name="${c.name}" neverSay=${(c.never_say || []).length} ` +
            `examples=${(c.example_answers || []).length}`
        );
      });
    }
    process.exit(0);
  }

  for (const file of FILES) {
    const p = path.join(COACHES_DIR, file);
    if (!fs.existsSync(p)) {
      console.error(`Missing persona file: ${p}`);
      process.exit(1);
    }
    const persona = JSON.parse(fs.readFileSync(p, 'utf8'));
    const key = persona.coachKey;
    if (!key) {
      console.error(`${file}: missing "coachKey" — cannot seed.`);
      process.exit(1);
    }
    await db
      .collection('coaches')
      .doc(key)
      .set(
        { ...persona, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: false }
      );
    console.log(`Seeded coaches/${key} (from ${file}, id=${persona.id})`);
  }
  process.exit(0);
}

main().catch((e) => {
  console.error('seed_coaches failed:', e);
  process.exit(1);
});
