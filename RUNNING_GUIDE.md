# BenchAlert: Running Guide

BenchAlert is now a production-ready application. The backend is hosted permanently on the cloud, so you usually **do not** need to run any local commands to use the app.

---

## 🚀 Standard Usage (Production)

### 1. Backend Status
The backend is live and always-on at:
**`https://insightful-harmony-production.up.railway.app`**

You do not need to run Python or Ngrok locally for the app to function.

### 2. Using the Mobile App
1.  **Download APK**: Get the latest **v7 APK** from the repository:
    `mobile/build/app/outputs/flutter-apk/app-release.apk`
2.  **Install**: Install it on any Android device.
3.  **Start Monitoring**: Just open the app and add cases. It will automatically connect to the Railway cloud server.

---

## 🛠️ Advanced: Local Development

If you want to modify the code or run the server locally for testing, follow these steps.

### A. Local Backend Setup
1.  **Navigate to Backend**: `cd backend`
2.  **Install Dependencies**: `pip install -r requirements.txt`
3.  **Run Locally**: `python main.py` (Server starts on port 8000)
4.  **Expose (Optional)**: If testing on a real phone locally, run `ngrok http 8000`.

### B. Local Mobile Setup
1.  **Navigate to Mobile**: `cd mobile`
2.  **Toggle URL**: Open `lib/providers/monitoring_provider.dart`.
3.  **Change Base URL**: Update `_baseUrl` to point to your `localhost` or `ngrok` link.
4.  **Run**: `flutter run`

---

## 📋 Features & Maintenance
- **Persistence**: Backend data is stored in a persistent Railway Volume at `/app/data`.
- **Background Service**: The app is optimized for background monitoring. Ensure "Battery Optimization" is disabled for BenchAlert for the most reliable alerts.
- **Auto-Deletion**: Cases are automatically removed from your local list once they have passed by more than 2 items on the live board.
- **Timestamping**: The app now tracks `updated_at` timestamps from the court board to ensure you are seeing real-time data.

---

## 📦 Building a New APK
If you make code changes and need a new installer:
1.  `cd mobile`
2.  `flutter pub get`
3.  `flutter build apk --release`
4.  Locate file at `build/app/outputs/flutter-apk/app-release.apk`
