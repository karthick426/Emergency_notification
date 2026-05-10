/**
 * Cloud Functions (Node.js) for SmartCityEmergencySystem.
 *
 * Required setup:
 * - firebase-admin
 * - firebase-functions
 * - Initialize admin SDK
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

function toNumber(v) {
  if (typeof v === "number") return v;
  if (typeof v === "string") return Number(v);
  return 0;
}

// Haversine distance in kilometers.
function haversineKm(startLat, startLng, endLat, endLng) {
  const R = 6371.0;
  const dLat = ((endLat - startLat) * Math.PI) / 180.0;
  const dLng = ((endLng - startLng) * Math.PI) / 180.0;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((startLat * Math.PI) / 180.0) *
      Math.cos((endLat * Math.PI) / 180.0) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

async function sendPushToUser({ userId, title, body, route }) {
  const userSnap = await admin.firestore().collection("users").doc(userId).get();
  const token = userSnap.exists ? userSnap.data().fcmToken : null;
  if (!token) return;

  // Data payload includes a route the app can interpret.
  const message = {
    token,
    notification: {
      title,
      body,
    },
    data: {
      route: route || "emergency",
    },
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          "content-available": 1,
        },
      },
    },
  };

  await admin.messaging().send(message);
}

// Simple in-memory rate limiter (For production, use Redis or a Firestore config document)
const RATE_LIMIT_WINDOW_MS = 60000; // 1 minute
async function isRateLimited(userId) {
  const rateLimitRef = admin.firestore().collection('rate_limits').doc(userId);
  return await admin.firestore().runTransaction(async (t) => {
    const doc = await t.get(rateLimitRef);
    const now = Date.now();
    if (doc.exists) {
      const data = doc.data();
      if (now - data.timestamp < RATE_LIMIT_WINDOW_MS) {
        if (data.count >= 3) {
           return true; // Rate limited (max 3 req per minute)
        }
        t.update(rateLimitRef, { count: data.count + 1 });
        return false;
      }
    }
    t.set(rateLimitRef, { timestamp: now, count: 1 });
    return false;
  });
}

exports.onRequestCreated = functions.firestore
  .document("requests/{requestId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const requestId = context.params.requestId;
    if (!data) return null;

    // Idempotency: if a request is already accepted with ambulance, do nothing.
    // (Prevents duplicate notifications if the function is re-triggered.)
    if (data.status === "accepted" && data.ambulanceId) return null;

    const userId = data.userId;
    const userLocation = data.userLocation || {};
    const userLat = toNumber(userLocation.latitude ?? userLocation.lat);
    const userLng = toNumber(userLocation.longitude ?? userLocation.lng);

    if (!userId) {
      console.warn("Request missing userId:", requestId);
      return null;
    }

    const limited = await isRateLimited(userId);
    if (limited) {
      console.warn("User rate limited:", userId);
      return null;
    }

    // 1) Ensure hospitalId is set to the nearest hospital if missing.
    let hospitalId = data.hospitalId;
    let hospitalLocation = null;

    if (!hospitalId || typeof hospitalId !== "string" || hospitalId.trim() === "") {
      const hospitalsSnap = await admin.firestore().collection("hospitals").get();
      let best = null;

      hospitalsSnap.forEach((doc) => {
        const h = doc.data();
        const loc = h.location || {};
        const lat = toNumber(loc.latitude ?? loc.lat);
        const lng = toNumber(loc.longitude ?? loc.lng);
        const dist = haversineKm(userLat, userLng, lat, lng);
        if (!best || dist < best.dist) {
          best = { dist, hospitalId: doc.id, hospitalLocation: { lat, lng } };
        }
      });

      if (!best) {
        console.warn("No hospitals configured.");
        return null;
      }

      hospitalId = best.hospitalId;
      hospitalLocation = best.hospitalLocation;
    } else {
      const hospitalSnap = await admin.firestore().collection("hospitals").doc(hospitalId).get();
      if (hospitalSnap.exists) {
        const h = hospitalSnap.data();
        const loc = h.location || {};
        hospitalLocation = {
          lat: toNumber(loc.latitude ?? loc.lat),
          lng: toNumber(loc.longitude ?? loc.lng),
        };
      }
    }

    if (!hospitalId || !hospitalLocation) {
      console.warn("Could not resolve hospital for request:", requestId);
      return null;
    }

    // Notify user that request is accepted (hospital found).
    await sendPushToUser({
      userId,
      title: "Request accepted",
      body: "A nearby hospital has been identified. An ambulance will be assigned shortly.",
      route: "emergency",
    }).catch((e) => console.warn("Push send failed (accepted):", e?.message || e));

    // Update request doc with hospitalId immediately (so UI has it).
    await admin.firestore().collection("requests").doc(requestId).set(
      {
        hospitalId,
        status: "accepted",
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 2) Assign nearest available ambulance using transactions to prevent double booking.
    const ambulancesSnap = await admin
      .firestore()
      .collection("ambulances")
      .where("status", "==", "available")
      .get();

    let candidateAmbulances = [];
    ambulancesSnap.forEach((doc) => {
      const a = doc.data();
      const loc = a.location || {};
      const lat = toNumber(loc.latitude ?? loc.lat);
      const lng = toNumber(loc.longitude ?? loc.lng);
      const dist = haversineKm(hospitalLocation.lat, hospitalLocation.lng, lat, lng);
      candidateAmbulances.push({ ambulanceId: doc.id, dist });
    });

    candidateAmbulances.sort((a, b) => a.dist - b.dist);

    let assignedAmbulanceId = null;

    for (const candidate of candidateAmbulances) {
      try {
        await admin.firestore().runTransaction(async (t) => {
          const ambRef = admin.firestore().collection("ambulances").doc(candidate.ambulanceId);
          const ambSnap = await t.get(ambRef);
          
          if (!ambSnap.exists || ambSnap.data().status !== "available") {
            throw new Error("Ambulance no longer available");
          }

          t.update(ambRef, {
            status: "assigned",
            assignedRequestId: requestId,
            assignedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        assignedAmbulanceId = candidate.ambulanceId;
        break; // Successfully assigned
      } catch (err) {
        // Collision happened, try next ambulance
        console.log(`Ambulance ${candidate.ambulanceId} taken, trying next...`);
      }
    }

    if (!assignedAmbulanceId) {
      // No ambulance available right now; request remains accepted but without ambulance.
      return null;
    }

    await admin.firestore().collection("requests").doc(requestId).set(
      {
        ambulanceId: assignedAmbulanceId,
      },
      { merge: true }
    );

    // Notify user that ambulance is assigned.
    await sendPushToUser({
      userId,
      title: "Ambulance assigned",
      body: "An ambulance has been assigned. Please stay near the pickup point.",
      route: "emergency",
    }).catch((e) => console.warn("Push send failed (assigned):", e?.message || e));

    return null;
  });

