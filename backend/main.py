from fastapi import FastAPI, Depends, HTTPException, Request
import time
from sqlalchemy.orm import Session
import models, database, scraper
from apscheduler.schedulers.background import BackgroundScheduler
import uvicorn
import os

app = FastAPI()

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    # Simple log to a file or print (which goes to Railway logs)
    log_msg = f"{request.method} {request.url.path} - Status: {response.status_code} - Duration: {duration:.4f}s"
    print(log_msg)
    with open("scraper.log", "a") as f:
        f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - INFO - {log_msg}\n")
    return response

# Initial database setup
database.Base.metadata.create_all(bind=database.engine)

scheduler = BackgroundScheduler()
scheduler.add_job(scraper.scrape_court_data, 'interval', minutes=1)
scheduler.start()

@app.get("/")
def read_root():
    return {"message": "Court Monitoring API is running"}

@app.get("/live-status")
def get_live_status(db: Session = Depends(database.get_db)):
    return db.query(models.LiveCourtStatus).all()

@app.get("/display-board")
def get_master_board(db: Session = Depends(database.get_db)):
    """Returns the full snapshot of the TSHC display board."""
    return db.query(models.MasterDisplayBoard).all()

@app.post("/scrape")
def trigger_scrape(db: Session = Depends(database.get_db)):
    """Force a scrape update right now."""
    scraper.scrape_court_data(force=True)
    return {"message": "Scrape completed"}

@app.get("/logs")
def get_logs():
    """Return the last 100 lines of the scraper log."""
    try:
        if os.path.exists("scraper.log"):
            with open("scraper.log", "r") as f:
                lines = f.readlines()
                return {"logs": lines[-100:]}
        return {"logs": ["Log file not found"]}
    except Exception as e:
        return {"error": str(e)}

@app.get("/cases")
def list_cases(db: Session = Depends(database.get_db)):
    return db.query(models.MasterCase).all()

@app.post("/cases")
def add_case(case: models.MasterCaseCreate, db: Session = Depends(database.get_db)):
    db_case = models.MasterCase(**case.dict())
    db.add(db_case)
    db.commit()
    db.refresh(db_case)
    return db_case

@app.patch("/cases/{case_id}")
def update_case(case_id: int, 
                advocate_name: str = None, 
                court_no: str = None, 
                case_number: str = None, 
                item_no: str = None, 
                alert_at: str = None, 
                db: Session = Depends(database.get_db)):
    db_case = db.query(models.MasterCase).filter(models.MasterCase.id == case_id).first()
    if not db_case:
        raise HTTPException(status_code=404, detail="Case not found")
    
    if advocate_name: db_case.advocate_name = advocate_name
    if court_no: db_case.court_no = court_no
    if case_number: db_case.case_number = case_number
    if item_no: db_case.item_no = item_no
    if alert_at: 
        db_case.alert_at = alert_at
        db_case.alert_sent = False # Reset alert if threshold changed
        
    db.commit()
    db.refresh(db_case)
    return db_case

@app.delete("/cases/{case_id}")
def delete_case(case_id: int, db: Session = Depends(database.get_db)):
    db_case = db.query(models.MasterCase).filter(models.MasterCase.id == case_id).first()
    if not db_case:
        raise HTTPException(status_code=404, detail="Case not found")
    db.delete(db_case)
    db.commit()
    return {"message": "Case deleted"}

@app.delete("/cases")
def clear_all_cases(db: Session = Depends(database.get_db)):
    db.query(models.MasterCase).delete()
    db.commit()
    return {"message": "All cases deleted"}

@app.patch("/cases/{case_id}/complete")
def complete_case(case_id: int, reason: str, db: Session = Depends(database.get_db)):
    db_case = db.query(models.MasterCase).filter(models.MasterCase.id == case_id).first()
    if not db_case:
        raise HTTPException(status_code=404, detail="Case not found")
    
    # Move to completed_cases table
    completed = models.CompletedCase(
        advocate_name=db_case.advocate_name,
        court_no=db_case.court_no,
        case_number=db_case.case_number,
        item_no=db_case.item_no,
        reason=reason
    )
    db.add(completed)
    db.delete(db_case)
    db.commit()
    return {"message": "Case moved to completed", "id": completed.id}

@app.get("/completed-cases")
def list_completed_cases(db: Session = Depends(database.get_db)):
    return db.query(models.CompletedCase).all()

@app.patch("/cases/{case_id}/acknowledge")
def acknowledge_case_alert(case_id: int, db: Session = Depends(database.get_db)):
    db_case = db.query(models.MasterCase).filter(models.MasterCase.id == case_id).first()
    if not db_case:
        raise HTTPException(status_code=404, detail="Case not found")
    db_case.alert_sent = True
    db.commit()
    return db_case

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
