import requests
from bs4 import BeautifulSoup
from database import SessionLocal
from models import LiveCourtStatus, MasterDisplayBoard
import re
from datetime import datetime, timedelta
import logging

# Set up logging
logging.basicConfig(
    filename='scraper.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

JSON_URL = "https://displayboard.tshc.gov.in/hcdbs/allcourtsdisplay"

def is_court_hours():
    # Railway/Cloud servers usually run in UTC. 
    # IST is UTC + 5:30
    now_utc = datetime.utcnow()
    now_ist = now_utc + timedelta(hours=5, minutes=30)
    
    # Monday = 0, Sunday = 6
    if now_ist.weekday() >= 5: # Saturday or Sunday
        return False
    # Official hours roughly 10:00 to 17:15 IST
    return 10 <= now_ist.hour < 17 or (now_ist.hour == 17 and now_ist.minute <= 15)

def scrape_court_data(force=False):
    if not force and not is_court_hours():
        print("Outside court hours. Skipping scrape.")
        return

    logging.info(f"Scraping court data from JSON API: {JSON_URL}")
    print("Scraping court data from JSON API:", JSON_URL)
    db = SessionLocal()
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'application/json'
    }
    try:
        response = requests.get(JSON_URL, headers=headers, timeout=15)
        if response.status_code != 200:
            logging.error(f"Failed to fetch data: {response.status_code}")
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
        logging.info(f"Successfully updated {len(data)} courts in master display board.")
        print(f"Successfully updated {len(data)} courts in master display board.")
    except Exception as e:
        logging.error(f"Error during JSON scraping: {e}")
        print(f"Error during JSON scraping: {e}")
        db.rollback()
    finally:
        db.close()
