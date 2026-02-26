import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

// Initialize Firebase Admin SDK
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

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
