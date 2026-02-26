

enum CaseStatus { safe, far, approaching, immediate }

class CourtCase {
  final int id;
  final String advocateName;
  final String courtNo;
  final String caseNumber;
  final String itemNo;  // String to handle 'S', 'P'
  final String alertAt; // String to handle 'S', 'P'
  bool alertSent;
  bool customAlertSent;
  String? currentRunningPosition; // String from live status

  CourtCase({
    required this.id,
    required this.advocateName,
    required this.courtNo,
    required this.caseNumber,
    required this.itemNo,
    required this.alertAt,
    this.alertSent = false,
    this.customAlertSent = false,
    this.currentRunningPosition,
  });

  CaseStatus get status {
    if (currentRunningPosition == null || currentRunningPosition == 'NS') return CaseStatus.safe;
    
    // Numerical checks
    int? r = int.tryParse(currentRunningPosition!);
    int? p = int.tryParse(itemNo);

    if (r != null && p != null) {
      int diff = p - r;
      
      // RED: 5 cases before up to 2 cases after (Difference ≤ 5 and >= -2)
      if (diff <= 5 && diff >= -2) return CaseStatus.immediate;
      
      // GREEN: 6 to 10 cases before (Difference 6–10)
      if (diff > 5 && diff <= 10) return CaseStatus.approaching;
      
      // BLUE: 11 to 15 cases before (Difference 11–15)
      if (diff > 10 && diff <= 15) return CaseStatus.far;

      // BLACK: Far from running (Difference > 15 or passed more than 2)
      return CaseStatus.safe;
    }

    // Fallback for non-numeric (e.g. 'S', 'P')
    if (currentRunningPosition == itemNo) return CaseStatus.immediate;
    
    return CaseStatus.safe;
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
      customAlertSent: json['custom_alert_sent'] == 1 || json['custom_alert_sent'] == true,
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
      'custom_alert_sent': customAlertSent ? 1 : 0,
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
      customAlertSent: map['custom_alert_sent'] == 1,
    );
  }
}
