import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

// Initialize Firebase Admin SDK
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

const revenuecatKey = defineSecret("REVENUECAT_SECRET_API_KEY");

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
