# Running Guide for Court Cases Monitoring App

Follow these steps to get the backend and mobile app running.

## 1. Backend Setup (Python)

The backend is built with FastAPI and uses a sqlite database.

### Prerequisites
- Python 3.8+
- [Ngrok](https://ngrok.com/) installed (to expose the backend)

### Installation
1.  **CRITICAL**: Navigate to the `backend` directory first:
    ```powershell
    cd "c:\Users\adbhu\Downloads\Court cases monitoring app\backend"
    ```
2.  (Optional but recommended) Create a virtual environment:
    ```powershell
    python -m venv venv
    .\venv\Scripts\activate
    ```
3.  Install dependencies:
    ```powershell
    pip install -r requirements.txt
    ```

### Running the Backend
1.  Start the FastAPI server:
    ```powershell
    python main.py
    ```
    The server will start at `http://0.0.0.0:8005`.

## 2. Expose Backend with Ngrok

Since the mobile app needs to communicate with your local server, you must use Ngrok.

1.  Open a new terminal and start Ngrok:
    ```powershell
    ngrok http 8005
    ```
2.  Copy the **Forwarding** URL (it looks like `https://xxxx-xxxx.ngrok-free.app`).

## 3. Mobile Setup (Flutter)

### Update API URL
1.  Open `mobile/lib/providers/monitoring_provider.dart`.
2.  Find line 18:
    ```dart
    String _baseUrl = 'https://kip-unsingable-kelsie.ngrok-free.dev';
    ```
3.  Replace the value with your new Ngrok URL from step 2.

### Running the App
1.  Navigate to the `mobile` directory:
    ```powershell
    cd "c:\Users\adbhu\Downloads\Court cases monitoring app\mobile"
    ```
2.  Get Flutter dependencies:
    ```powershell
    flutter pub get
    ```
3.  Run the app (ensure an emulator is running or a device is connected):
    ```powershell
    flutter run
    ```

### Building the APK
To create a standalone Android app (APK) for installation:
1.  Navigate to the `mobile` directory:
    ```powershell
    cd "c:\Users\adbhu\Downloads\Court cases monitoring app\mobile"
    ```
2.  Run the build command:
    ```powershell
    flutter build apk --release
    ```
3.  The generated APK will be located at:
    `build\app\outputs\flutter-apk\app-release.apk`

## Notes
- **Scraping**: The backend automatically scrapes live court data every minute while court is in session.
- **Vibration/Alerts**: Alerts and vibration are triggered when a tracked case reaches "Red" status.
