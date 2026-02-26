from database import SessionLocal
from models import LiveCourtStatus

db = SessionLocal()
results = db.query(LiveCourtStatus).limit(20).all()

print("Live Court Status dump (total found: " + str(db.query(LiveCourtStatus).count()) + "):")
for r in results:
    print(f"Court: {r.court_no}, RunningPos: {r.running_position}, Status: {r.status}")

db.close()
