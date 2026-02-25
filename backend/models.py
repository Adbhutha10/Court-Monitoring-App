from sqlalchemy import Column, Integer, String, Boolean, DateTime, func
from database import Base
from pydantic import BaseModel

class MasterCase(Base):
    __tablename__ = "master_cases"

    id = Column(Integer, primary_key=True, index=True)
    advocate_name = Column(String)
    court_no = Column(String)
    case_number = Column(String)
    item_no = Column(String)  # Changed to String to handle 'S', 'P', etc.
    alert_at = Column(String) # Changed to String to handle 'S', 'P', etc.
    alert_sent = Column(Boolean, default=False)

class LiveCourtStatus(Base):
    __tablename__ = "live_court_status"

    court_no = Column(String, primary_key=True, index=True)
    running_position = Column(String)
    status = Column(String, default="active") # Added to track 'disposed' etc.
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

class MasterDisplayBoard(Base):
    __tablename__ = "master_display_board"

    court_no = Column(String, primary_key=True, index=True)
    running_position = Column(String)
    case_number = Column(String)
    status = Column(String, default="active")
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

class CompletedCase(Base):
    __tablename__ = "completed_cases"

    id = Column(Integer, primary_key=True, index=True)
    advocate_name = Column(String)
    court_no = Column(String)
    case_number = Column(String)
    item_no = Column(String)
    completion_time = Column(DateTime, server_default=func.now())
    reason = Column(String) # e.g., "Passed", "Disposed", "Finished"

class MasterCaseCreate(BaseModel):
    advocate_name: str
    court_no: str
    case_number: str
    item_no: str
    alert_at: str
