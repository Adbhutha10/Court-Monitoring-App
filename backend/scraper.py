import requests
from bs4 import BeautifulSoup
from database import SessionLocal
from models import LiveCourtStatus, MasterDisplayBoard
import re
from datetime import datetime

JSON_URL = "https://displayboard.tshc.gov.in/hcdbs/allcourtsdisplay"

def is_court_hours():
    now = datetime.now()
    # Monday = 0, Sunday = 6
    if now.weekday() >= 5: # Saturday or Sunday
        return False
    # Official hours roughly 10:00 to 17:15
    return 10 <= now.hour < 17 or (now.hour == 17 and now.minute <= 15)

def scrape_court_data(force=False):
    if not force and not is_court_hours():
        print("Outside court hours. Skipping scrape.")
        return

    print("Scraping court data from JSON API:", JSON_URL)
    db = SessionLocal()
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'application/json'
    }
    try:
        response = requests.get(JSON_URL, headers=headers, timeout=15)
        if response.status_code != 200:
            print(f"Failed to fetch data: {response.status_code}")
            return

        data = response.json()
        
        # Mark all current courts as "finished" initially. 
        db.query(LiveCourtStatus).update({LiveCourtStatus.status: "finished"})
        db.commit()

        for court in data:
            # "courtNo" in JSON is like "1", "2", "30"
            raw_court_no = court.get("courtNo", "")
            if not raw_court_no:
                continue
            
            # Map to "C01", "C02" etc to match the App's expectation
            try:
                # If it's a number, pad it
                court_num = int(raw_court_no)
                court_id = f"C{court_num:02d}"
            except ValueError:
                # If it's not a number, just prepend C
                court_id = f"C{raw_court_no.upper().replace(' ', '')}"
            
            item_no = court.get("itemNo", "0")
            case_details = court.get("caseDetails", "")
            
            # Detect status
            status_text = "active"
            if item_no == "CSE":
                status_text = "finished"
                item_no = "Court Finished"
            elif item_no == "NS":
                status_text = "not in session"
            elif "disposed" in item_no.lower():
                status_text = "disposed"
            
            # 1. Update LiveCourtStatus
            live_status = db.query(LiveCourtStatus).filter(LiveCourtStatus.court_no == court_id).first()
            if live_status:
                live_status.running_position = item_no
                live_status.status = status_text
            else:
                db.add(LiveCourtStatus(court_no=court_id, running_position=item_no, status=status_text))
            
            # 2. Update MasterDisplayBoard
            master_entry = db.query(MasterDisplayBoard).filter(MasterDisplayBoard.court_no == court_id).first()
            if master_entry:
                master_entry.running_position = item_no
                master_entry.case_number = case_details
                master_entry.status = status_text
            else:
                db.add(MasterDisplayBoard(
                    court_no=court_id,
                    running_position=item_no,
                    case_number=case_details,
                    status=status_text
                ))
        
        db.commit()
        print(f"Successfully updated {len(data)} courts in master display board.")
    except Exception as e:
        print(f"Error during JSON scraping: {e}")
        db.rollback()
    finally:
        db.close()
