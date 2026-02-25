## Features

- **Multi-User Privacy**: Tracked cases are stored locally on each device using SQLite, ensuring users only see their own cases.
- **Live Monitoring**: Fetches real-time court status from the TSHC display board.
- **Smart Alerts**: Persistent vibration and notifications when cases reach "approaching" or "immediate" status.
- **FastAPI Backend**: Efficiently scrapes and serves court data.

## Project Structure

- `backend/`: FastAPI application, scraper, and database logic.
- `mobile/`: Flutter mobile application with local SQLite storage.
- `RUNNING_GUIDE.md`: Comprehensive setup and execution guide.
