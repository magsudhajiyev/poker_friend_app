import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { mirrorFromSubscriber, SubscriptionMirror } from "./subscription_mirror";
import {
  allowedOrigin,
  isFreshSync,
  responseFromMirror,
  responseFromSaved,
} from "./subscription_sync";
import { shouldSendTrialReminder, trialReminderCopy } from "./trial_reminder";
import { dailyAccuracy } from "./daily_accuracy";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, Timestamp, QueryDocumentSnapshot } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { createHash, randomUUID } from "crypto";
import {
  resolveSlot,
  isQuietNow,
  lapsedWholeDays,
  reEngageDue,
  sentInLapseCount,
  dayLimitReached,
  chooseType,
  pickReconcileTarget,
  flagAllows,
  needsDailyChallengeFlag,
} from "./engagement_policy";
import * as functionsV1 from "firebase-functions/v1";
import { chunk } from "./chunk_refs";
import { staleCutoffKey, isStaleStreakRow } from "./streak_expiry";

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
    // Optional coach image (engagement pushes) — shown as the large/expanded
    // image so the coach appears IN the notification.
    const imageUrl: string | undefined =
      typeof notificationData.imageUrl === "string"
        ? notificationData.imageUrl
        : undefined;

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
        ...(imageUrl ? { imageUrl } : {}),
      },
      data: payload,
      tokens: tokens,
      android: {
        notification: {
          channelId: "poker_events",
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
          ...(imageUrl ? { imageUrl } : {}),
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "default",
            // Image attachments require a Notification Service Extension on
            // iOS (contentAvailable alone won't render the image); Android
            // shows it directly. The coach image is a nice-to-have, so iOS
            // simply gets the text until/unless the NSE is added.
            contentAvailable: true,
          },
        },
        ...(imageUrl ? { fcmOptions: { imageUrl } } : {}),
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

/** RevenueCat REST call failed (non-2xx). */
class RcFetchError extends Error {}

/**
 * Re-fetch the subscriber from the RC REST API and derive the mirror (pure,
 * unit-tested in src/subscription_mirror.ts). Shared by revenuecatWebhook and
 * syncSubscription so the two cannot drift.
 */
async function fetchSubscriptionMirror(uid: string): Promise<SubscriptionMirror> {
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
    { headers: { "Authorization": `Bearer ${revenuecatKey.value()}` } }
  );
  if (!response.ok) {
    const body = await response.text();
    console.error(`RC subscriber fetch failed for ${uid}: HTTP ${response.status} ${body}`);
    throw new RcFetchError(`HTTP ${response.status}`);
  }
  const subscriber = (await response.json()).subscriber;
  return mirrorFromSubscriber(subscriber, Date.now());
}

/** users/{uid} fields the mirror writes (rules + trial reminders read them). */
function mirrorFields(m: SubscriptionMirror) {
  return {
    subscriptionTier: m.tier,
    subscriptionTierExpiresAt:
      m.expiresAtMs === null ? null : Timestamp.fromMillis(m.expiresAtMs),
    // Free-trial mirror — the server-side "trial ends tomorrow"
    // reminder reads these (hard paywall step 4).
    subscriptionInTrial: m.inTrial,
    subscriptionWillRenew: m.willRenew,
    subscriptionProductId: m.productId,
    tierSyncedAt: FieldValue.serverTimestamp(),
  };
}

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
        const m = await fetchSubscriptionMirror(uid);
        await db.collection("users").doc(uid).set(mirrorFields(m), { merge: true });
        console.log(`Mirrored tier for ${uid}: ${m.tier}`);
      }
      res.status(200).send("OK");
    } catch (error) {
      if (error instanceof RcFetchError) {
        // Non-2xx → RevenueCat retries the webhook later.
        res.status(502).send("RC fetch failed");
        return;
      }
      console.error(`Webhook processing failed for ${appUserId}:`, error);
      res.status(500).send("Internal error");
    }
  }
);

/**
 * syncSubscription — the web dashboard calls this at login to learn the
 * user's REAL paid plan (the webhook mirror alone is not trusted yet). The
 * uid comes only from the verified Firebase ID token. Refreshes the mirror
 * from RevenueCat, except: a sync under 60 s old is returned as saved, and a
 * missing users/{uid} doc is never created here (grantFreeMonthOnSignup fires
 * on create). RC failure → 502 and the mirror is left untouched.
 */
export const syncSubscription = onRequest(
  { secrets: [revenuecatKey], timeoutSeconds: 30 },
  async (req, res) => {
    const origin = allowedOrigin(req.headers.origin);
    if (origin) {
      res.set("Access-Control-Allow-Origin", origin);
      res.set("Vary", "Origin");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
    }
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    const authHeader = req.headers.authorization ?? "";
    const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    let uid: string;
    try {
      uid = (await getAuth().verifyIdToken(idToken)).uid;
    } catch {
      res.status(401).send("Unauthorized");
      return;
    }

    try {
      const userRef = db.collection("users").doc(uid);
      const user = await userRef.get();
      const syncedAt = user.get("tierSyncedAt") as Timestamp | undefined;
      if (user.exists && isFreshSync(syncedAt ? syncedAt.toMillis() : null, Date.now())) {
        const exp = user.get("subscriptionTierExpiresAt") as Timestamp | null | undefined;
        const saved = responseFromSaved(
          user.get("subscriptionTier"),
          exp ? exp.toMillis() : null,
          user.get("subscriptionInTrial")
        );
        if (saved) {
          res.status(200).json(saved);
          return;
        }
      }

      const m = await fetchSubscriptionMirror(uid);
      if (user.exists) await userRef.update(mirrorFields(m));
      res.status(200).json(responseFromMirror(m));
    } catch (error) {
      if (error instanceof RcFetchError) {
        res.status(502).json({ error: "rc_unavailable" });
        return;
      }
      console.error(`syncSubscription failed for ${uid}:`, error);
      res.status(500).json({ error: "internal" });
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
        // Log ElevenLabs' own reason (e.g. "quota_exceeded" arrives as a 401,
        // which looks like a bad key without the body). Truncated; the body
        // never contains the API key.
        const reason = (await ttsResponse.text().catch(() => "")).slice(0, 300);
        console.error(
          `ElevenLabs ${ttsResponse.status} for coach=${coach} uid=${uid}: ${reason}`
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
 * Scoring: see src/daily_accuracy.ts (mirrors lib/services/daily_scoring.dart).
 */
export const validateLeaderboardEntry = onDocumentCreated(
  "leaderboard_daily/{dayKey}/entries/{uid}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const verdicts: string = typeof data.verdicts === "string" ? data.verdicts : "";

    // Reward reconcile: a new leaderboard entry == the user played today.
    // Stamp the most recent un-played engagement event for this uid with the
    // 2-hour reward (covers SERVER-sent pushes; device pushes self-reconcile
    // on-device). Best-effort — never blocks the score validation below.
    const uid = event.params.uid;
    try {
      const nowMs = Date.now();
      // Past-or-now events only (same uid+sentAt index); the pure picker
      // still skips device, offer and admin events, so fetch a wide window.
      const pending = await db
        .collection("notification_events")
        .where("uid", "==", uid)
        .where("sentAt", "<=", Timestamp.fromMillis(nowMs))
        .orderBy("sentAt", "desc")
        .limit(25)
        .get();
      const candidates = pending.docs.map((ev) => {
        const d = ev.data();
        const sentAt = d.sentAt;
        return {
          ...d,
          sentMs: sentAt && typeof sentAt.toMillis === "function" ? sentAt.toMillis() : 0,
        };
      });
      const idx = pickReconcileTarget(candidates, nowMs);
      if (idx >= 0) {
        const within2h = nowMs - candidates[idx].sentMs <= 2 * 60 * 60 * 1000;
        await pending.docs[idx].ref.update({
          playedAt: FieldValue.serverTimestamp(),
          convertedWithin2h: within2h,
        });
      }
    } catch (err) {
      console.error("engagement reconcile failed:", err);
    }

    // Re-grade from verdicts + pot weights (the only trusted inputs).
    const trueScore = dailyAccuracy(verdicts, data.weights);
    const trueScoreKey = Math.round(trueScore * 10);
    const letters = verdicts.replace(/\|/g, "");
    const truePerfect = letters.length > 0 && /^c+$/.test(letters);

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

/* ────────────────────────────────────────────────────────────────────────
   Engagement send-time scheduler (Phase 2)
   Hourly job that fires each user's push around THEIR active hour. Reads the
   send-time signal (users/{uid}.notif.activeHourUtc, written nightly by the
   web repo's cron-send-times job) + the device tz offset, matches the user's
   current local hour, applies the Duolingo guardrails, and writes a
   user_notifications doc (fires FCM via sendPushNotification) + a
   notification_events doc (dashboard + reward loop).
   See docs/features/engagement-notifications-plan.md §12.
   ──────────────────────────────────────────────────────────────────────── */

// Coach-voiced copy, server-side (mirrors lib/services/notification_copy.dart
// for the server-reachable moments). Kept intentionally small; the client
// catalog is the richer source for device-scheduled pushes.
const SERVER_COPY: Record<string, { title: string; body: string }[]> = {
  dc_streak_risk: [
    { title: "Your streak ends tonight", body: "Five quick hands keep your {n}-day streak alive." },
    { title: "Don't lose your streak", body: "A {n}-day streak is on the line — play today's five before midnight." },
  ],
  dc_today_ready: [
    { title: "Today's five are live", body: "A fresh daily challenge just dropped — take your shot." },
    { title: "Your daily challenge is ready", body: "Five new decisions, two minutes. Your coach is waiting." },
  ],
  lb_milestone: [
    { title: "🔥 {n}-day streak!", body: "That's a new personal best. Keep it rolling tomorrow." },
    { title: "Milestone reached: {n} days", body: "You're on a roll — your coach is impressed." },
  ],
  re_engage: [
    { title: "Your coaches are ready when you are", body: "Pick up where you left off — five quick decisions, no pressure." },
    { title: "The table's still here", body: "A fresh daily challenge is waiting whenever you feel like it." },
  ],
};

function pickCopy(type: string, seed: number, streak: number) {
  const pool = SERVER_COPY[type] || SERVER_COPY["re_engage"];
  const c = pool[Math.abs(seed) % pool.length];
  return { title: c.title, body: c.body.replace("{n}", String(streak)) };
}

// Hosted coach mascots (same files the email template uses) — shown IN the
// push as the expanded image. Keep in sync with public/email/coach-*.png.
const COACH_IMAGE_URL: Record<string, string> = {
  grinder: "https://finaltable.io/email/coach-duke.png",
  professor: "https://finaltable.io/email/coach-vega.png",
  nova: "https://finaltable.io/email/coach-nova.png",
};

export const scheduleEngagement = onSchedule(
  { schedule: "0 * * * *", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const nowMs = Date.now();
    const utcHourNow = new Date(nowMs).getUTCHours();

    // Flags are read once per run; if that fails, send nothing.
    let flags: Record<string, unknown>;
    let adminIds: Set<string>;
    try {
      const [flagDoc, admins] = await Promise.all([
        db.collection("app_config").doc("feature_flags").get(),
        db.collection("app_admins").get(),
      ]);
      flags = (flagDoc.data() || {}) as Record<string, unknown>;
      adminIds = new Set(admins.docs.map((d) => d.id));
    } catch (err) {
      console.error("scheduleEngagement flag read failed:", err);
      return;
    }

    // Candidates: users whose send hour (activeHourUtc - 1) is now, plus
    // admin test sends. Equality filters only, so single-field indexes do.
    const [dueSnap, forcedSnap] = await Promise.all([
      db.collection("users").where("notif.activeHourUtc", "==", (utcHourNow + 1) % 24).get(),
      db.collection("users").where("notif.debugForceSend", "==", true).get(),
    ]);
    const candidates = new Map<string, QueryDocumentSnapshot>();
    for (const d of [...dueSnap.docs, ...forcedSnap.docs]) candidates.set(d.id, d);

    let sent = 0;
    for (const doc of candidates.values()) {
      try {
        const uid = doc.id;
        const notif = (doc.get("notif") || {}) as Record<string, unknown>;

        // ONE send slot per user (activeHourUtc - 1, UTC). The admin test
        // hook bypasses the holdout + the slot so a forced push fires on the
        // very next run, whatever the hour.
        const slot = resolveSlot(uid, notif, nowMs);
        if (!slot.evaluate) continue;
        const forced = slot.forced;

        // Dark-launch gate (admin test sends bypass it).
        const isAdmin = adminIds.has(uid);
        if (!forced && !flagAllows(flags["engagement_notifications"], isAdmin)) continue;

        // Undeliverable users get no event and no push.
        const tokens = await db
          .collection("fcm_tokens")
          .where("userId", "==", uid)
          .limit(1)
          .get();
        if (tokens.empty) continue;

        // One engagement push per user per day, device or server. Equality
        // filters only (merged single-field indexes); cancelled device
        // reminders do not count.
        const dayEvents = await db
          .collection("notification_events")
          .where("uid", "==", uid)
          .where("dayKey", "==", slot.today)
          .get();
        if (!forced && dayLimitReached(dayEvents.docs.map((d) => d.data()))) continue;

        // Resolve the eligible moment (priority order; server-reachable set).
        const streakDoc = await db.collection("leaderboard_streak").doc(uid).get();
        const lastActive = doc.get("lastActiveAt") as Timestamp | undefined;
        const lastActiveMs = lastActive ? lastActive.toMillis() : null;
        const lapsedDays = lapsedWholeDays(lastActiveMs, nowMs);

        // Comeback ladder (days 2/5/14): count this lapse's pushes so far.
        let reEngageSentInLapse = 0;
        if (reEngageDue(lapsedDays, 0)) {
          const prior = await db
            .collection("notification_events")
            .where("uid", "==", uid)
            .where("type", "==", "re_engage")
            .where("source", "==", "server")
            .get();
          reEngageSentInLapse = sentInLapseCount(
            prior.docs.map((d) => (d.get("sentAt") as Timestamp | undefined)?.toMillis() ?? null),
            lastActiveMs
          );
        }

        const { type, currentStreak } = chooseType({
          notif,
          slot,
          quiet: isQuietNow(notif, slot),
          lastDayKey: String(streakDoc.get("lastDayKey") || ""),
          streakRaw: Number(streakDoc.get("currentStreak") || 0),
          bestStreak: Number(streakDoc.get("bestStreak") || 0),
          lapsedDays,
          reEngageSentInLapse,
        });
        if (!type) continue;
        if (
          !forced &&
          needsDailyChallengeFlag(type) &&
          !flagAllows(flags["daily_challenge"], isAdmin)
        ) continue;

        // Clear the one-shot debug flag so it doesn't re-fire every hour.
        if (forced) {
          await doc.ref.set(
            { notif: { debugForceSend: false } },
            { merge: true }
          );
        }

        const coach = String(notif.coachId || "neutral");
        const copy = pickCopy(type, currentStreak + utcHourNow, currentStreak);

        // Create the event doc first so its id rides in the FCM data payload.
        const eventRef = db.collection("notification_events").doc();
        await eventRef.set({
          uid,
          type,
          coach,
          variantId: 0,
          source: "server",
          scheduledHourLocal: slot.localNow,
          scheduledHourUtc: utcHourNow,
          dayKey: slot.today,
          sentAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
        });

        // Fire the push via the existing sendPushNotification pipeline.
        const coachImage = COACH_IMAGE_URL[coach];
        await db.collection("user_notifications").add({
          userId: uid,
          title: copy.title,
          body: copy.body,
          type,
          ...(coachImage ? { imageUrl: coachImage } : {}),
          data: {
            action: "daily_challenge",
            type,
            notificationEventId: eventRef.id,
          },
          createdAt: FieldValue.serverTimestamp(),
        });
        sent++;
      } catch (err) {
        console.error("scheduleEngagement user error:", err);
      }
    }

    console.log(`scheduleEngagement: hour=${utcHourNow} sent=${sent}`);
  }
);

/* ────────────────────────────────────────────────────────────────────────
   Free-trial reminder BACKUP (hard paywall step 4)
   The app schedules "your free trial ends tomorrow" on the device and stamps
   users/{uid}.trialReminderScheduledForMs. This hourly job only covers users
   whose device did not (deleted app, phone off, notifications blocked):
   trial ending within 24 h (≥ 2 h left), renewing, no matching device stamp,
   not sent yet. Decision is pure + tested (src/trial_reminder.ts). Trial
   users are few, so it reads them with one equality query (no new index).
   ──────────────────────────────────────────────────────────────────────── */
export const sendTrialReminders = onSchedule("every 60 minutes", async () => {
  const now = Date.now();
  const snap = await db.collection("users")
    .where("subscriptionInTrial", "==", true)
    .get();
  let sent = 0;
  for (const doc of snap.docs) {
    try {
      const d = doc.data();
      const exp = d.subscriptionTierExpiresAt;
      const expiresAtMs =
        exp && typeof exp.toMillis === "function" ? exp.toMillis() : null;
      const state = {
        subscriptionInTrial: d.subscriptionInTrial,
        subscriptionWillRenew: d.subscriptionWillRenew,
        subscriptionTier: d.subscriptionTier,
        expiresAtMs,
        trialReminderScheduledForMs: d.trialReminderScheduledForMs ?? null,
        trialReminderSentForMs: d.trialReminderSentForMs ?? null,
      };
      if (!shouldSendTrialReminder(state, now)) continue;
      const copy = trialReminderCopy(d.subscriptionTier);
      // Mark first, then send: a crash between the two skips one push
      // rather than risking a duplicate on the next run.
      await doc.ref.set({ trialReminderSentForMs: expiresAtMs }, { merge: true });
      await db.collection("user_notifications").add({
        userId: doc.id,
        title: copy.title,
        body: copy.body,
        type: "trial_reminder",
        data: { action: "trial_reminder", type: "trial_reminder" },
        createdAt: FieldValue.serverTimestamp(),
      });
      sent++;
    } catch (err) {
      console.error(`sendTrialReminders failed for ${doc.id}:`, err);
    }
  }
  console.log(`sendTrialReminders: ${snap.size} in trial, ${sent} reminded`);
});

/**
 * GDPR / Google Play data deletion: when a Firebase Auth account is deleted,
 * remove the user's public Daily Challenge leaderboard data. Rules make
 * leaderboard entries create-only for clients, so this must run server-side.
 *
 * Uses the v1 auth trigger (v2 has no auth onDelete). uid comes from the
 * auth event, never from client input.
 *
 * DEPLOY BY NAME ONLY: `firebase deploy --only functions:deleteLeaderboardDataOnUserDelete`
 * A full functions deploy would delete three prod functions not in this repo.
 */
// Retries enabled: deleting already-missing docs is a no-op, so re-runs are safe (idempotent).
export const deleteLeaderboardDataOnUserDelete = functionsV1
  .runWith({ failurePolicy: true })
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const db = getFirestore();
    const refs: FirebaseFirestore.DocumentReference[] = [
      db.collection("leaderboard_streak").doc(uid),
    ];
    const entries = await db.collectionGroup("entries").where("uid", "==", uid).get();
    // Collection group "entries" may exist elsewhere; only touch leaderboard_daily.
    for (const d of entries.docs) {
      if (d.ref.path.startsWith("leaderboard_daily/")) refs.push(d.ref);
    }
    for (const part of chunk(refs, 500)) {
      const batch = db.batch();
      part.forEach((r) => batch.delete(r));
      await batch.commit();
    }
    console.log(`deleteLeaderboardDataOnUserDelete: ${refs.length} docs removed for ${uid}`);
  });

/* ────────────────────────────────────────────────────────────────────────
   expireStaleStreaks — nightly Daily Challenge streak-board hygiene.

   Lapsed players keep leaderboard_streak.currentStreak > 0 forever, which
   piles them at the top of the board and inflates count()-based ranks. Once
   a day, zero currentStreak on rows whose lastDayKey is older than
   (UTC today - 2 days). bestStreak / perfectDays / totalPlayed are kept.

   Query: `currentStreak > 0` ordered by currentStreak (automatic single-field
   index, no composite). Rows already at 0 never match, so the nightly scan
   does not grow with lapsed players. `lastDayKey < cutoff` is checked in code
   (isStaleStreakRow). Paging uses the last DocumentSnapshot as cursor
   (lastDayKey/currentStreak are not unique). Zeroing a row removes it from
   the result set, but startAfter(snapshot) positions by the (currentStreak,
   __name__) values captured when the page was read, not by a live lookup,
   so committing each page's batch before fetching the next skips nothing.
   Pure logic: src/streak_expiry.ts (tested).

   DEPLOY BY NAME ONLY: `firebase deploy --only functions:expireStaleStreaks`.
   A full functions deploy would delete three prod functions that are not in
   this repo.
   ──────────────────────────────────────────────────────────────────────── */
export const expireStaleStreaks = onSchedule(
  { schedule: "every day 06:00", timeZone: "Etc/UTC" },
  async () => {
    const cutoff = staleCutoffKey(Date.now());
    const PAGE = 500;
    let cursor: QueryDocumentSnapshot | null = null;
    let expired = 0;
    for (;;) {
      let q = db.collection("leaderboard_streak")
        .where("currentStreak", ">", 0)
        .orderBy("currentStreak")
        .limit(PAGE);
      if (cursor !== null) q = q.startAfter(cursor);
      const snap = await q.get();
      if (snap.empty) break;
      const batch = db.batch();
      let n = 0;
      for (const doc of snap.docs) {
        if (!isStaleStreakRow(doc.data(), cutoff)) continue;
        batch.update(doc.ref, { currentStreak: 0 });
        n++;
      }
      if (n > 0) await batch.commit();
      expired += n;
      cursor = snap.docs[snap.docs.length - 1];
      if (snap.size < PAGE) break;
    }
    console.log(`expireStaleStreaks: cutoff=${cutoff} expired=${expired}`);
  },
);
