const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendAlertNotification = onDocumentCreated(
  "sensor_logs/{docId}",
  async (event) => {
    // Ambil data dari dokumen yang baru dibuat
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const waterLevel = data.water_level || 0;
    const debitValue = data.water_debit || 0;

    // Logika kondisi bahaya
    if (waterLevel >= 1.0 || debitValue > 20.0) {
      const message = {
        notification: {
          title: "⚠️ PERINGATAN BAHAYA",
          body: `Ketinggian air ${waterLevel}M! ${debitValue > 20 ? "Hujan Ekstrem!" : ""}`,
        },
        topic: "alerts", // Pastikan aplikasi Flutter sudah subscribe ke topic "alerts"
      };

      // Kirim notifikasi melalui Firebase Admin SDK
      try {
        await admin.messaging().send(message);
        console.log("Notifikasi berhasil dikirim!");
      } catch (error) {
        console.error("Gagal mengirim notifikasi:", error);
      }
    }
  },
);
