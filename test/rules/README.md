# Firestore rules tests

Tests `leaderboard_daily` and `leaderboard_streak` in `../../firestore.rules`.
Runs on the local emulator with the `demo-rules-test` project. Nothing touches prod.

Run (from the repo root):

    cd test/rules && npm install
    firebase emulators:exec --only firestore --project demo-rules-test "node --test leaderboard.rules.test.js"

Needs Java 21+ (firebase-tools 15 requirement) and Node 20+.
