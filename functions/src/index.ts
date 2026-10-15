import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { createHash, randomUUID } from "crypto";

// Initialize Firebase Admin SDK
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

const revenuecatKey = defineSecret("REVENUECAT_SECRET_API_KEY");
// Shared secret RevenueCat sends as the Authorization header on webhook
// calls (configured in the RC dashboard webhook settings).
const rcWebhookAuth = defineSecret("RC_WEBHOOK_AUTH");

/**
 * Cloud Function: Send FCM push notification when a new user notification is created
 *
 * Triggers on: user_notifications collection document creation
 */
export const sendPushNotification = onDocumentCreated(
  "user_notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const notificationData = snapshot.data();
    const notificationId = event.params.notificationId;

    console.log(`Processing notification ${notificationId}:`, notificationData);

    // Skip if FCM was already sent via club topic
    if (notificationData.skipFcm === true) {
      console.log(`Skipping FCM for ${notificationId} - already sent via club topic`);
      return;
    }

    // Get the target user ID
    const userId = notificationData.userId;
    if (!userId) {
      console.error("No userId in notification document");
      return;
    }

    // Get notification content
    const title = notificationData.title || "Poker Logger";
    const body = notificationData.body || "";
    const data = notificationData.data || {};

    // Add notification type and IDs to data payload for deep linking
    const payload: { [key: string]: string } = {
      notificationId: notificationId,
      type: notificationData.type || "general",
      ...Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
    };

    // Get user's FCM tokens
    const tokensSnapshot = await db
      .collection("fcm_tokens")
      .where("userId", "==", userId)
      .get();

    if (tokensSnapshot.empty) {
      console.log(`No FCM tokens found for user ${userId}`);
      return;
    }

    const tokens = tokensSnapshot.docs.map((doc) => doc.data().token as string);
    console.log(`Found ${tokens.length} FCM tokens for user ${userId}`);

    // Build the FCM message
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: payload,
      tokens: tokens,
      android: {
        notification: {
          channelId: "poker_events",
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "default",
            contentAvailable: true,
          },
        },
      },
    };

    try {
      // Send to all tokens
      const response = await messaging.sendEachForMulticast(message);

      console.log(
        `FCM send result: ${response.successCount} success, ${response.failureCount} failures`
      );

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const tokensToDelete: string[] = [];

        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errorCode = resp.error?.code;
            if (
              errorCode === "messaging/invalid-registration-token" ||
              errorCode === "messaging/registration-token-not-registered"
            ) {
              tokensToDelete.push(tokens[idx]);
            }
            console.error(`Error sending to token ${idx}:`, resp.error);
          }
        });

        // Delete invalid tokens
        if (tokensToDelete.length > 0) {
          console.log(`Cleaning up ${tokensToDelete.length} invalid tokens`);
          const batch = db.batch();
          for (const token of tokensToDelete) {
            const tokenDoc = tokensSnapshot.docs.find(
              (doc) => doc.data().token === token
            );
            if (tokenDoc) {
              batch.delete(tokenDoc.ref);
            }
          }
          await batch.commit();
        }
      }

      console.log(`Success: sent to ${response.successCount} devices`);
    } catch (error) {
      console.error("Error sending FCM notification:", error);
    }
  }
);

/**
 * Cloud Function: Send FCM to all club members (topic-based)
 */
export const sendClubNotification = onDocumentCreated(
  "clubs/{clubId}/notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const notificationData = snapshot.data();
    const clubId = event.params.clubId;
    const notificationId = event.params.notificationId;

    console.log(
      `Processing club notification ${notificationId} for club ${clubId}:`,
      notificationData
    );

    const title = notificationData.title || "Club Update";
    const body = notificationData.body || "";
    const data = notificationData.data || {};

    // Build data payload
    const payload: { [key: string]: string } = {
      notificationId: notificationId,
      clubId: clubId,
      type: notificationData.type || "general",
      ...Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
    };

    // Build the FCM message for topic
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: payload,
      topic: `club_${clubId}`,
      android: {
        notification: {
          channelId: "poker_events",
          priority: "high" as const,
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "default",
          },
        },
      },
    };

    try {
      const response = await messaging.send(message);
      console.log(`FCM topic message sent: ${response}`);
    } catch (error) {
      console.error("Error sending FCM topic notification:", error);
    }
  }
);

/**
 * Cloud Function: Launch promo — grant 1 month of free Pro to new sign-ups.
 *
 * Triggers once per new user (users/{uid} is only ever created by
 * AuthService._createUserDocument, guarded by a doc-exists check). Gated by
 * the super-admin toggle app_config/promotions.freeMonthOnSignup. The grant
 * is a RevenueCat promotional entitlement, so its expiry is computed and
 * enforced by RC's servers — the client never runs any expiry logic.
 */
export const grantFreeMonthOnSignup = onDocumentCreated(
  { document: "users/{userId}", secrets: [revenuecatKey] },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }
    const userId = event.params.userId;

    // Toggle gate — fail closed: no doc, missing field, or read error all
    // mean "promo off".
    try {
      const promoDoc = await db.collection("app_config").doc("promotions").get();
      if (promoDoc.data()?.freeMonthOnSignup !== true) {
        return;
      }
    } catch (error) {
      console.error("Promo toggle read failed, skipping grant:", error);
      return;
    }

    // Strict-new guard: the users doc can also be backfilled for an old
    // account that never had one (ensureUserDocument). Only auth accounts
    // created within the last hour count as new sign-ups.
    try {
      const authUser = await getAuth().getUser(userId);
      const createdMs = Date.parse(authUser.metadata.creationTime);
      if (!Number.isFinite(createdMs) || Date.now() - createdMs > 60 * 60 * 1000) {
        console.log(`Skipping promo for ${userId}: auth account is not new`);
        return;
      }
    } catch (error) {
      console.error(`Auth lookup failed for ${userId}, skipping grant:`, error);
      return;
    }

    // Grant the promotional entitlement. app_user_id in RevenueCat is the
    // Firebase uid (Purchases.logIn(uid) on every sign-in path).
    try {
      // Ensure the RC customer exists first — the promotional endpoint does
      // NOT auto-create subscribers (404 code 7259), and this trigger
      // usually beats the client's Purchases.logIn(uid). GET
      // returns-or-creates the customer.
      const ensureResponse = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
        { headers: { "Authorization": `Bearer ${revenuecatKey.value()}` } }
      );
      if (!ensureResponse.ok) {
        const body = await ensureResponse.text();
        console.error(
          `RevenueCat customer ensure failed for ${userId}: HTTP ${ensureResponse.status} ${body}`
        );
        return;
      }

      const response = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}` +
          "/entitlements/pro/promotional",
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${revenuecatKey.value()}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ duration: "monthly" }),
        }
      );
      if (!response.ok) {
        const body = await response.text();
        console.error(
          `RevenueCat grant failed for ${userId}: HTTP ${response.status} ${body}`
        );
        return;
      }
    } catch (error) {
      console.error(`RevenueCat grant request failed for ${userId}:`, error);
      return;
    }

    // Marker for the client's post-tour promo paywall variant. An update
    // cannot re-trigger this onDocumentCreated function.
    try {
      await snapshot.ref.update({
        freeMonthGranted: true,
        freeMonthGrantedAt: FieldValue.serverTimestamp(),
      });
      console.log(`Free Pro month granted to new user ${userId}`);
    } catch (error) {
      // Entitlement is already live in RC; only the celebratory UI signal is
      // lost. Log and move on.
      console.error(`Failed to write freeMonthGranted marker for ${userId}:`, error);
    }
  }
);

/**
 * Scheduled function to clean up old FCM tokens (runs daily)
 */
export const cleanupOldTokens = onSchedule(
  { schedule: "every 24 hours" },
  async () => {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 60);

    console.log(`Cleaning up FCM tokens older than ${cutoffDate.toISOString()}`);

    const { Timestamp } = await import("firebase-admin/firestore");

    const oldTokensSnapshot = await db
      .collection("fcm_tokens")
      .where("updatedAt", "<", Timestamp.fromDate(cutoffDate))
      .get();

    if (oldTokensSnapshot.empty) {
      console.log("No old tokens to clean up");
      return;
    }

    console.log(`Found ${oldTokensSnapshot.size} old tokens to delete`);

    const batch = db.batch();
    oldTokensSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`Deleted ${oldTokensSnapshot.size} old FCM tokens`);
  }
);

/**
 * Social feed phase 4: "X is playing" push when a shared session goes live.
 *
 * Followers subscribe to topic `live_{userId}` at follow time
 * (FollowService), so ONE topic message reaches everyone — no per-follower
 * fan-out writes (audit B6 pattern). Fires on feed_sessions create; the doc
 * may be a bare ensure-upsert (no sessionName) when the presence write
 * failed, which is still the moment the session became visible.
 */
export const notifyFollowersOnSessionStart = onDocumentCreated(
  "feed_sessions/{sessionId}",
  async (event) => {
    const data = event.data?.data();
    const userId = data?.userId as string | undefined;
    if (!userId) return;
    // Never announce sessions that are already over (ensure-upsert created
    // by publishSessionEnd after a fully-offline session).
    if (data?.status === "ended") return;

    const userName = (data?.userName as string) || "A player";
    const sessionName = (data?.sessionName as string) || "";
    const gameType = (data?.gameType as string) || "";
    const detail = [sessionName, gameType].filter((s) => s.length > 0).join(" · ");

    const notification = {
      title: `${userName} is playing 🔴`,
      body: detail.length > 0 ? detail : "Live session started",
    };
    const messageData = {
      action: "view_feed",
      sessionId: event.params.sessionId,
      userId: userId,
    };

    try {
      // PRIMARY: direct token fan-out. Topic delivery depends on every
      // follower device having successfully subscribed client-side — which
      // failed silently in the field (bug 2026-08-06). Tokens are
      // server-registered on every app start, so this path is guaranteed
      // for any device that can receive pushes at all.
      const followsSnap = await db
        .collection("follows")
        .where("followedId", "==", userId)
        .get();
      const followerIds = followsSnap.docs
        .map((d) => d.data().followerId as string | undefined)
        .filter((id): id is string => typeof id === "string" && id.length > 0);

      const tokens: string[] = [];
      for (let i = 0; i < followerIds.length; i += 10) {
        const chunk = followerIds.slice(i, i + 10);
        const tokSnap = await db
          .collection("fcm_tokens")
          .where("userId", "in", chunk)
          .get();
        tokSnap.docs.forEach((d) => {
          const t = (d.data().token as string) || d.id;
          if (t) tokens.push(t);
        });
      }

      // channelId MUST be the app's registered channel ("poker_events") —
      // Android silently drops notifications sent to an unknown/blocked
      // channel even when app notifications are allowed (bug 2026-08-06:
      // this exact miss ate every went-live push).
      const androidConfig = {
        notification: {
          channelId: "poker_events",
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      };
      const apnsConfig = { payload: { aps: { sound: "default" } } };

      if (tokens.length > 0) {
        for (let i = 0; i < tokens.length; i += 500) {
          const resp = await messaging.sendEachForMulticast({
            tokens: tokens.slice(i, i + 500),
            notification,
            data: messageData,
            apns: apnsConfig,
            android: androidConfig,
          });
          console.log(
            `went-live multicast for ${userId}: ${resp.successCount}/${tokens.length} delivered`
          );
        }
      } else {
        console.log(`went-live: no follower tokens for ${userId}`);
      }

      // SECONDARY: topic send kept for devices whose token doc is missing
      // but whose topic subscription survived.
      await messaging.send({
        topic: `live_${userId}`,
        notification,
        data: messageData,
        apns: apnsConfig,
        android: androidConfig,
      });
    } catch (error) {
      console.error(`Went-live push failed for ${userId}:`, error);
    }
  }
);

/**
 * RevenueCat webhook → mirror the subscription tier onto users/{uid}.
 *
 * Firestore rules cannot see RevenueCat entitlements, so paid-gated
 * features (social feed) check the mirrored `subscriptionTier` +
 * `subscriptionTierExpiresAt` on the user doc. Registered in the RC
 * dashboard with the RC_WEBHOOK_AUTH value as the Authorization header.
 *
 * Strategy: on ANY event, re-fetch the subscriber from the RC REST API and
 * derive the tier from active entitlements — no per-event-type logic, so
 * renewals, cancellations, expirations, transfers and refunds all converge
 * to the same source of truth.
 */
export const revenuecatWebhook = onRequest(
  { secrets: [revenuecatKey, rcWebhookAuth] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }
    if (req.headers.authorization !== rcWebhookAuth.value()) {
      console.error("Webhook auth mismatch");
      res.status(401).send("Unauthorized");
      return;
    }

    // TRANSFER events carry transferred_from/transferred_to instead of
    // app_user_id (review finding) — re-mirror EVERY affected uid so the
    // old account's stale paid mirror is corrected immediately.
    const event = req.body?.event ?? {};
    const uids: string[] = [
      event.app_user_id,
      ...(Array.isArray(event.transferred_from) ? event.transferred_from : []),
      ...(Array.isArray(event.transferred_to) ? event.transferred_to : []),
    ].filter(
      (id: unknown): id is string =>
        typeof id === "string" && id.length > 0 && !id.startsWith("$RCAnonymousID:")
    );
    const appUserId = uids[0];
    if (uids.length === 0) {
      // Anonymous RC customers have no Firebase uid to mirror onto.
      res.status(200).send("Ignored (no app user id)");
      return;
    }

    try {
      for (const uid of uids) {
        const response = await fetch(
          `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
          { headers: { "Authorization": `Bearer ${revenuecatKey.value()}` } }
        );
        if (!response.ok) {
          const body = await response.text();
          console.error(
            `RC subscriber fetch failed for ${uid}: HTTP ${response.status} ${body}`
          );
          // Non-2xx → RevenueCat retries the webhook later.
          res.status(502).send("RC fetch failed");
          return;
        }
        const subscriber = (await response.json()).subscriber;
        const entitlements: Record<string, { expires_date: string | null }> =
          subscriber?.entitlements ?? {};

        // Highest active entitlement wins; expires_date null = lifetime.
        const now = Date.now();
        const isActive = (id: string) => {
          const e = entitlements[id];
          if (!e) return false;
          return e.expires_date === null || Date.parse(e.expires_date) > now;
        };
        const tier = isActive("club") ? "club"
          : isActive("elite") ? "elite"
          : isActive("pro") ? "pro"
          : "free";

        let expiresAt: Timestamp | null = null;
        if (tier !== "free") {
          const raw = entitlements[tier].expires_date;
          expiresAt = raw === null
            ? Timestamp.fromMillis(now + 100 * 365 * 24 * 3600 * 1000) // lifetime
            : Timestamp.fromDate(new Date(raw));
        }

        await db.collection("users").doc(uid).set(
          {
            subscriptionTier: tier,
            subscriptionTierExpiresAt: expiresAt,
            tierSyncedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        console.log(`Mirrored tier for ${uid}: ${tier}`);
      }
      res.status(200).send("OK");
    } catch (error) {
      console.error(`Webhook processing failed for ${appUserId}:`, error);
      res.status(500).send("Internal error");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────
// Daily Challenge coach voice — ElevenLabs TTS proxy with Storage caching.
//
// The app never holds the ElevenLabs key: signed-in clients POST
// { text, coach } here, the function synthesizes the line (or serves the
// cached MP3) and returns a tokened download URL. Clips are cached in
// Storage keyed by sha256(coach|text) — the daily puzzle is identical for
// every user, so the first player to hear a line pays for its generation
// and everyone else streams the cache. Voice casting + delivery settings
// live HERE (not client-requestable) so the key can't be abused for
// arbitrary synthesis.
// ─────────────────────────────────────────────────────────────────────────

const elevenLabsKey = defineSecret("ELEVENLABS_API_KEY");

/** Persona → ElevenLabs premade voice + delivery. All original characters. */
const COACH_VOICES: Record<
  string,
  { voiceId: string; stability: number; similarityBoost: number }
> = {
  // Duke — old-school Vegas grinder → "Bill" (wise, mature, old American)
  grinder: {
    voiceId: "pqHfZKP75CvOlQylNhV4",
    stability: 0.45,
    similarityBoost: 0.8,
  },
  // Prof. Vega — dry GTO theorist → "George" (warm, captivating British
  // storyteller; recast from "Daniel" which read as generic/robotic)
  professor: {
    voiceId: "JBFqnCBsd6RMkjVDRZzb",
    stability: 0.55,
    similarityBoost: 0.8,
  },
  // Nova — high-energy female hype coach → "Laura" (enthusiast, quirky)
  nova: {
    voiceId: "FGY2WhTYpPnrIDTdsKH5",
    stability: 0.3,
    similarityBoost: 0.8,
  },
};

// Coach lines are 1-4 sentences, and the client's notation expansion
// ("A2o" → "ace two offsuit") grows them further — 400 proved too tight
// (verbose mistake explanations 400'd and the coach went mute). The
// client also trims to ~550 at a sentence boundary as a backstop.
const COACH_TEXT_MAX = 600;

export const coachSpeech = onRequest(
  // minInstances keeps one instance warm: cold starts added 1-3s to the
  // first coach line of a session, which reads as the coach "lagging".
  // Costs a few $/month idle — drop to 0 if the feature is shelved.
  { secrets: [elevenLabsKey], timeoutSeconds: 30, minInstances: 1 },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    // Firebase Auth required — signed-in app users only.
    const authHeader = req.headers.authorization ?? "";
    const idToken = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7)
      : "";
    let uid: string;
    try {
      uid = (await getAuth().verifyIdToken(idToken)).uid;
    } catch {
      res.status(401).send("Unauthorized");
      return;
    }

    const text = typeof req.body?.text === "string" ? req.body.text.trim() : "";
    const coach = typeof req.body?.coach === "string" ? req.body.coach : "";
    const voice = COACH_VOICES[coach];
    if (!voice || text.length === 0 || text.length > COACH_TEXT_MAX) {
      res.status(400).send("Bad request");
      return;
    }

    // voiceId is part of the key so RECASTING a coach invalidates that
    // coach's cached clips (bug 2026-10-14: Vega's recast kept serving
    // old-voice clips for previously generated lines).
    const hash = createHash("sha256")
      .update(`${coach}|${voice.voiceId}|${text}`)
      .digest("hex");
    const bucket = getStorage().bucket();
    const file = bucket.file(`coach_voice/${coach}/${hash}.mp3`);

    const urlFor = (token: string) =>
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
      `${encodeURIComponent(file.name)}?alt=media&token=${token}`;

    try {
      // Cache hit: reuse the stored clip's download token.
      const [exists] = await file.exists();
      if (exists) {
        const [meta] = await file.getMetadata();
        const token = (meta.metadata as Record<string, string> | undefined)?.[
          "firebaseStorageDownloadTokens"
        ];
        if (token) {
          res.status(200).json({ url: urlFor(token), cached: true });
          return;
        }
        // Clip without a token (shouldn't happen) — fall through, regenerate.
      }

      const ttsResponse = await fetch(
        `https://api.elevenlabs.io/v1/text-to-speech/${voice.voiceId}` +
          `?output_format=mp3_44100_64`,
        {
          method: "POST",
          headers: {
            "xi-api-key": elevenLabsKey.value(),
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            text,
            model_id: "eleven_flash_v2_5",
            voice_settings: {
              stability: voice.stability,
              similarity_boost: voice.similarityBoost,
            },
          }),
        }
      );
      if (!ttsResponse.ok) {
        console.error(
          `ElevenLabs ${ttsResponse.status} for coach=${coach} uid=${uid}`
        );
        res.status(502).send("TTS failed");
        return;
      }

      const audio = Buffer.from(await ttsResponse.arrayBuffer());
      const token = randomUUID();
      await file.save(audio, {
        contentType: "audio/mpeg",
        metadata: { metadata: { firebaseStorageDownloadTokens: token } },
      });
      res.status(200).json({ url: urlFor(token), cached: false });
    } catch (error) {
      console.error(`coachSpeech failed for uid=${uid}:`, error);
      res.status(500).send("Internal error");
    }
  }
);

/**
 * validateLeaderboardEntry — trust-but-verify for the Daily Challenge
 * leaderboard. The puzzle is identical for everyone per day, so the score is
 * derivable purely from the submitted `verdicts`. The client writes an
 * advisory `score`; this function re-derives it and overwrites `score` +
 * `scoreKey` if they disagree, so no one can post a fake score through the
 * rules (which only shape-check). Fires on daily-entry create.
 *
 * Scoring matches the client (DailyChallengeService.scoreOf): c=1, o=0.5,
 * anything else=0. A valid run has exactly 5 verdict letters.
 */
export const validateLeaderboardEntry = onDocumentCreated(
  "leaderboard_daily/{dayKey}/entries/{uid}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const verdicts: string = typeof data.verdicts === "string" ? data.verdicts : "";

    // Re-grade from verdicts (the only trusted input).
    let trueScore = 0;
    for (const ch of verdicts) {
      if (ch === "c") trueScore += 1;
      else if (ch === "o") trueScore += 0.5;
    }
    const trueScoreKey = Math.round(trueScore * 10);
    const truePerfect = verdicts.length === 5 && /^c{5}$/.test(verdicts);

    const clientScore = typeof data.score === "number" ? data.score : -1;
    const clientKey = typeof data.scoreKey === "number" ? data.scoreKey : -1;
    const clientPerfect = data.perfect === true;

    const needsFix =
      clientScore !== trueScore ||
      clientKey !== trueScoreKey ||
      clientPerfect !== truePerfect;

    if (!needsFix) return; // client was honest — nothing to do

    try {
      await snap.ref.update({
        score: trueScore,
        scoreKey: trueScoreKey,
        perfect: truePerfect,
        validatedAt: FieldValue.serverTimestamp(),
      });
      console.log(
        `Leaderboard: corrected ${event.params.uid} on ${event.params.dayKey} ` +
          `(${clientScore}->${trueScore})`
      );
    } catch (error) {
      console.error("validateLeaderboardEntry update failed:", error);
    }
  }
);
