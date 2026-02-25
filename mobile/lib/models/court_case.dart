import 'package:flutter/foundation.dart';

enum CaseStatus { safe, far, approaching, immediate }

class CourtCase {
  final int id;
  final String advocateName;
  final String courtNo;
  final String caseNumber;
  final String itemNo;  // String to handle 'S', 'P'
  final String alertAt; // String to handle 'S', 'P'
  bool alertSent;
  String? currentRunningPosition; // String from live status

  CourtCase({
    required this.id,
    required this.advocateName,
    required this.courtNo,
    required this.caseNumber,
    required this.itemNo,
    required this.alertAt,
    this.alertSent = false,
    this.currentRunningPosition,
  });

  CaseStatus get status {
    if (currentRunningPosition == null || currentRunningPosition == 'NS') return CaseStatus.safe;
    
    // Numerical checks
    int? r = int.tryParse(currentRunningPosition!);
    int? p = int.tryParse(itemNo);

    if (r != null && p != null) {
      int diff = p - r;
      
      // RED: Immediate / Running (Difference ≤ 1 or Board already past/at Item)
      if (diff <= 1) return CaseStatus.immediate;
      
      // GREEN: Approaching (Difference 2–5)
      if (diff >= 2 && diff <= 5) return CaseStatus.approaching;
      
      // BLUE: Far from running (Difference > 5)
      if (diff > 5) return CaseStatus.far;
    }

    // Fallback for non-numeric (e.g. 'S', 'P')
    if (currentRunningPosition == itemNo) return CaseStatus.immediate;
    
    return CaseStatus.far;
  }

  int? get remainingCount {
    if (currentRunningPosition == null) return null;
    int? r = int.tryParse(currentRunningPosition!);
    int? p = int.tryParse(itemNo);
    if (r != null && p != null) return p - r;
    return null;
  }

  factory CourtCase.fromJson(Map<String, dynamic> json) {
    return CourtCase(
      id: json['id'],
      advocateName: json['advocate_name'],
      courtNo: json['court_no'],
      caseNumber: json['case_number'],
      itemNo: json['item_no'].toString(),
      alertAt: json['alert_at'].toString(),
      alertSent: json['alert_sent'] == 1 || json['alert_sent'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id == 0 ? null : id, // Let SQLite handle autoincrement if id is 0
      'advocate_name': advocateName,
      'court_no': courtNo,
      'case_number': caseNumber,
      'item_no': itemNo,
      'alert_at': alertAt,
      'alert_sent': alertSent ? 1 : 0,
    };
  }

  factory CourtCase.fromMap(Map<String, dynamic> map) {
    return CourtCase(
      id: map['id'],
      advocateName: map['advocate_name'],
      courtNo: map['court_no'],
      caseNumber: map['case_number'],
      itemNo: map['item_no'],
      alertAt: map['alert_at'],
      alertSent: map['alert_sent'] == 1,
    );
  }
}
