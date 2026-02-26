import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/court_case.dart';
import '../helpers/database_helper.dart';

class MonitoringProvider with ChangeNotifier {
  List<CourtCase> _trackedCases = [];
  bool _isLoading = false;
  DateTime? _lastUpdated;
  String? _connectionError;
  Timer? _refreshTimer;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  CourtCase? _activeAlertCase;
  bool _isVibrating = false;
  String _baseUrl = 'https://unbeckoned-elisha-tetanically.ngrok-free.dev'; // Public Ngrok Tunnel (.dev suffix)

  String get baseUrl => _baseUrl;
  List<CourtCase> get trackedCases => _trackedCases;
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;
  String? get connectionError => _connectionError;
  CourtCase? get activeAlertCase => _activeAlertCase;

  MonitoringProvider() {
    _init();
  }

  Future<void> _init() async {
    await _initNotifications();
    await fetchTrackedCases();
    _startAutoRefresh();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);

    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isLoading) fetchLiveStatus();
    });
  }

  Future<void> fetchTrackedCases() async {
    _isLoading = true;
    _connectionError = null;
    notifyListeners();
    try {
      _trackedCases = await DatabaseHelper().getCases();
      await fetchLiveStatus();
    } catch (e) {
      _connectionError = "Error loading local cases: $e";
      debugPrint('Error fetching tracked cases: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLiveStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/live-status'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        _connectionError = null;
        final List<dynamic> liveData = json.decode(response.body);
        
        bool changed = false;
        List<CourtCase> casesToComplete = [];
        Map<int, String> completionReasons = {};

        for (var caseItem in _trackedCases) {
          final courtData = liveData.firstWhere(
            (element) => element['court_no'] == caseItem.courtNo,
            orElse: () => null,
          );
          
          if (courtData != null) {
            String newPos = courtData['running_position'].toString();
            String courtStatus = courtData['status'] ?? 'active';

            if (caseItem.currentRunningPosition != newPos) {
              caseItem.currentRunningPosition = newPos;
              changed = true;
              _checkAlerts(caseItem);
            }

            // Auto-removal triggers
            int? r = int.tryParse(newPos);
            int? p = int.tryParse(caseItem.itemNo);
            
            bool shouldRemove = false;
            String reason = "Completed";

            if (courtStatus == 'disposed') {
              shouldRemove = true;
              reason = "Disposed";
            } else if (courtStatus == 'finished') {
              shouldRemove = true;
              reason = "Court Finished";
            } else if (r != null && p != null && (p - r) < -2) {
              shouldRemove = true;
              reason = "Case Passed (2+ items)";
            }

            if (shouldRemove) {
              casesToComplete.add(caseItem);
              completionReasons[caseItem.id] = reason;
            }
          } else {
            // Court not in live list at all. 
            // DON'T REMOVE. Just set current position to null or "NS"
            if (caseItem.currentRunningPosition != 'NS') {
              caseItem.currentRunningPosition = 'NS';
              changed = true;
            }
          }
        }
        
        for (var item in casesToComplete) {
          await moveCaseToCompleted(item.id, completionReasons[item.id] ?? "Unknown");
        }

        _lastUpdated = DateTime.now();
        if (changed || casesToComplete.isNotEmpty || true) notifyListeners();
      } else {
        _connectionError = "Live update failed: ${response.statusCode}";
        notifyListeners();
      }
    } catch (e) {
      _connectionError = "Sync error: $e";
      notifyListeners();
    }
  }

  Future<void> moveCaseToCompleted(int id, String reason) async {
    try {
      // For now, we'll just remove it from the local tracked list.
      // In a more complex app, you'd have a 'completed_cases' table locally.
      await DatabaseHelper().deleteCase(id);
      _trackedCases.removeWhere((element) => element.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error moving case to completed: $e');
      _trackedCases.removeWhere((element) => element.id == id);
      notifyListeners();
    }
  }

  void _checkAlerts(CourtCase caseItem) {
    bool vibrationTriggered = false;

    // 1. Custom 'Alert At' trigger
    // Trigger when running position reaches or passes the user's defined alertAt
    int? currentPos = int.tryParse(caseItem.currentRunningPosition ?? '');
    int? alertAtPos = int.tryParse(caseItem.alertAt);

    if (currentPos != null && alertAtPos != null && currentPos >= alertAtPos && !caseItem.customAlertSent) {
      caseItem.customAlertSent = true;
      _triggerPersistentVibration();
      _showLocalNotification(caseItem, "ALERT: Board reached ${caseItem.alertAt}!");
      vibrationTriggered = true;
      DatabaseHelper().updateCase(caseItem); // Persist flag
    }

    // 2. Original 'Red Status' trigger (Immediate)
    if (caseItem.status == CaseStatus.immediate && !caseItem.alertSent) {
      caseItem.alertSent = true;
      if (!vibrationTriggered) _triggerPersistentVibration();
      _showLocalNotification(caseItem, "CASE REACHED RED STATUS!");
      DatabaseHelper().updateCase(caseItem); // Persist flag
    }
    
    if (vibrationTriggered || caseItem.alertSent) {
       _activeAlertCase = caseItem;
       notifyListeners();
    }
  }

  Future<void> _showLocalNotification(CourtCase caseItem, String title) async {
    final androidDetails = AndroidNotificationDetails(
      'court_alerts',
      'Court Alerts',
      channelDescription: 'Notifications for court case updates',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );
    final notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      caseItem.id,
      title,
      'Court ${caseItem.courtNo}: Case ${caseItem.caseNumber} is live!',
      notificationDetails,
    );
  }

  Future<void> _triggerSingleVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 1000);
    }
  }

  Future<void> testVibration() async {
    await _triggerPersistentVibration();
  }

  Future<void> _triggerPersistentVibration() async {
    if (_isVibrating) return;
    try {
      if (await Vibration.hasVibrator() ?? false) {
        _isVibrating = true;
        debugPrint('Triggering persistent vibration...');
        // Pattern: [wait, vibrate, wait, vibrate...]
        // [0, 1000, 500, 1000, 500...] starts immediately
        Vibration.vibrate(
          pattern: [0, 1000, 500, 1000, 500, 1000, 500, 1000], 
          repeat: 0, 
        );
        
        // Auto-stop after 30s
        Timer(const Duration(seconds: 30), () {
          if (_isVibrating) dismissAlert();
        });
      } else {
        debugPrint('Device reported no vibrator found.');
      }
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }

  void dismissAlert() {
    _activeAlertCase = null;
    _isVibrating = false;
    Vibration.cancel();
    notifyListeners();
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    notifyListeners();
    fetchTrackedCases();
  }

  Future<bool> addCase(String advocateName, String courtNo, String caseNumber, String itemNo, String alertAt) async {
    try {
      _connectionError = null;
      _isLoading = true; // Use loading state during add
      notifyListeners();
      
      final newCase = CourtCase(
        id: 0, 
        advocateName: advocateName,
        courtNo: courtNo,
        caseNumber: caseNumber,
        itemNo: itemNo,
        alertAt: alertAt,
      );

      final id = await DatabaseHelper().insertCase(newCase);
      debugPrint('Successfully inserted case with ID: $id');
      
      // Reload everything from DB to ensure state is correct
      await fetchTrackedCases();
      
      return true;
    } catch (e) {
      _connectionError = "Local database error: $e";
      debugPrint('Add case error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateCase({
    required int id,
    String? advocateName,
    String? courtNo,
    String? caseNumber,
    String? itemNo,
    String? alertAt,
  }) async {
    try {
      final index = _trackedCases.indexWhere((element) => element.id == id);
      if (index != -1) {
        final existingCase = _trackedCases[index];
        final updatedCase = CourtCase(
          id: existingCase.id,
          advocateName: advocateName ?? existingCase.advocateName,
          courtNo: courtNo ?? existingCase.courtNo,
          caseNumber: caseNumber ?? existingCase.caseNumber,
          itemNo: itemNo ?? existingCase.itemNo,
          alertAt: alertAt ?? existingCase.alertAt,
          // Reset flags if critical values changed
          alertSent: (itemNo == null || itemNo == existingCase.itemNo) ? existingCase.alertSent : false,
          customAlertSent: (alertAt == null || alertAt == existingCase.alertAt) ? existingCase.customAlertSent : false,
          currentRunningPosition: existingCase.currentRunningPosition,
        );

        await DatabaseHelper().updateCase(updatedCase);
        _trackedCases[index] = updatedCase;
        notifyListeners();
        fetchLiveStatus();
      }
    } catch (e) {
      _connectionError = "Local update failed: $e";
      notifyListeners();
    }
  }

  Future<void> removeCase(int id) async {
    try {
      await DatabaseHelper().deleteCase(id);
      _trackedCases.removeWhere((element) => element.id == id);
      notifyListeners();
    } catch (e) {
      _connectionError = "Local delete failed: $e";
      notifyListeners();
    }
  }

  Future<void> clearAllCases() async {
    try {
      await DatabaseHelper().deleteAllCases();
      _trackedCases.clear();
      notifyListeners();
    } catch (e) {
      _connectionError = "Local clear failed: $e";
      notifyListeners();
    }
  }

  Future<void> acknowledgeAlert(int id) async {
    try {
      final index = _trackedCases.indexWhere((element) => element.id == id);
      if (index != -1) {
        _trackedCases[index].alertSent = true;
        _trackedCases[index].customAlertSent = true;
        await DatabaseHelper().updateCase(_trackedCases[index]);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error acknowledging alert locally: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
