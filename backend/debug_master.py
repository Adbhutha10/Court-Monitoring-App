from database import SessionLocal
from models import MasterDisplayBoard

db = SessionLocal()
results = db.query(MasterDisplayBoard).limit(10).all()

print("Master Display Board dump (first 10):")
for r in results:
    print(f"Court: {r.court_no}, RunningPos: {r.running_position}, CaseNumber: {r.case_number}")

db.close()
