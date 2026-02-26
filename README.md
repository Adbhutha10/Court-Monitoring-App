# BenchAlert ⚖️⏰

**BenchAlert** is a high-performance court case monitoring system designed for advocates and legal professionals. It provides real-time tracking of court proceedings, automated alerts, and background monitoring to ensure you never miss a case call.

---

## 🚀 Key Features

### 1. Real-Time Court Status
- **Live Scraping**: The backend automatically scrapes live data from the TSHC display board every 60 seconds.
- **Dynamic Board Updates**: The mobile app reflects the current running item number for all courts (C01 - C40) instantly.

### 2. Personal Case Tracking
- **Individual Watchlist**: Add specific cases you are interested in with details like Advocate Name, Court Number, Case Number, and Target Item Number.
- **Local SQLite Storage**: All your tracked cases are stored locally on your device. Your data stays on your phone and is not shared with a central server, ensuring privacy and offline access to your list.

### 3. Smart Alert System
- **Proactive Alerts**: Set a custom "Alert At" item number. The app will notify you when the court reaches that position.
- **Color-Coded Urgency**:
  - 🔵 **Blue**: Case is far off (> 5 items).
  - 🟢 **Green**: Case is approaching (2-5 items).
  - 🔴 **Red**: Case is immediate (<= 1 item).
- **Persistent Vibration**: When a case enters the "Immediate" zone or reaches your alert point, the device triggers a persistent vibration pattern that continues until manually dismissed.

### 4. Background Monitoring Service
- **Close & Forget**: Even if you close the app or kill it from the task switcher, the **Background Monitoring Service** continues to poll the server.
- **Independent Operation**: The service runs as a foreground process on Android, ensuring the operating system doesn't kill the monitoring logic, keeping you updated 24/7.

---

## 🛠 Technology Stack

### Mobile (Frontend)
- **Flutter**: Cross-platform framework for a premium, responsive UI.
- **Sqflite**: Local SQLite database for case management.
- **Flutter Background Service**: For persistent background polling.
- **Local Notifications**: Highly visible alerts with custom vibration patterns.

### Backend
- **FastAPI**: High-performance Python web framework for serving the API.
- **Scrapy/BeautifulSoup**: Robust scraping logic to extract data from court display boards.
- **Ngrok Integration**: Secure tunneling to allow mobile devices to communicate with local development servers.

---

## 📂 Project Structure

- `mobile/`: The Flutter source code, including providers, models, and background workers.
- `backend/`: Python source code, including the FastAPI server (`main.py`) and scraper logic (`scraper.py`).
- `RUNNING_GUIDE.md`: Detailed setup instructions for both backend and mobile teams.

---

## ⚙️ Setup & Installation

Please refer to the [RUNNING_GUIDE.md](RUNNING_GUIDE.md) for a step-by-step walkthrough on setting up the environment, configuring the Ngrok tunnel, and building the release APK.

---

## 🎨 Icon & Design
BenchAlert features a custom legal-themed logo and a clean, dark-mode-ready interface designed to be "glanceable" in a busy court environment.

---

## 📝 License
Proprietary. Developed for Court Monitoring.
