import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/court_case.dart';

class MonitoringProvider with ChangeNotifier {
  List<CourtCase> _trackedCases = [];
  bool _isLoading = false;
  DateTime? _lastUpdated;
  String? _connectionError;
  Timer? _refreshTimer;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  CourtCase? _activeAlertCase;
  bool _isVibrating = false;
  String _baseUrl = 'https://kip-unsingable-kelsie.ngrok-free.dev'; // Public Ngrok Tunnel (.dev suffix)

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
      final response = await http.get(
        Uri.parse('$_baseUrl/cases'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _trackedCases = data.map((e) => CourtCase.fromJson(e)).toList();
        await fetchLiveStatus();
      } else {
        _connectionError = "Server returned ${response.statusCode}";
      }
    } catch (e) {
      _connectionError = "Connection error: $e";
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

            // Auto-removal triggers - DISABLED to keep cases in list
            /*
            if (courtStatus == 'disposed') {
              casesToComplete.add(caseItem);
              completionReasons[caseItem.id] = "Disposed";
            } else if (courtStatus == 'finished') {
              casesToComplete.add(caseItem);
              completionReasons[caseItem.id] = "Court Finished";
            } else if (caseItem.status == CaseStatus.completed) {
              casesToComplete.add(caseItem);
              completionReasons[caseItem.id] = "Numeric Completion";
            }
            */
          } else {
            // Court not in live list at all. 
            // DON'T REMOVE. Just set current position to null or "NS"
            if (caseItem.currentRunningPosition != 'NS') {
              caseItem.currentRunningPosition = 'NS';
              changed = true;
            }
          }
        }
        
        // Auto-completion is now disabled for the entry screen
        /*
        for (var item in casesToComplete) {
          await moveCaseToCompleted(item.id, completionReasons[item.id] ?? "Unknown");
        }
        */

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
      final response = await http.patch(
        Uri.parse('$_baseUrl/cases/$id/complete?reason=$reason'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        _trackedCases.removeWhere((element) => element.id == id);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error moving case to completed: $e');
      _trackedCases.removeWhere((element) => element.id == id);
      notifyListeners();
    }
  }

  void _checkAlerts(CourtCase caseItem) {
    // Alert when status is Red (Board >= Item - 1)
    if (caseItem.status == CaseStatus.immediate && _activeAlertCase?.id != caseItem.id) {
      _activeAlertCase = caseItem;
      _triggerPersistentVibration();
      _showLocalNotification(caseItem, "CASE REACHED RED STATUS!");
      notifyListeners();
    }
  }

  Future<void> _showLocalNotification(CourtCase caseItem, String title) async {
    const androidDetails = AndroidNotificationDetails(
      'court_alerts',
      'Court Alerts',
      channelDescription: 'Notifications for court case updates',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    
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

  Future<void> _triggerPersistentVibration() async {
    if (_isVibrating) return;
    if (await Vibration.hasVibrator() ?? false) {
      _isVibrating = true;
      // Vibrate in pattern for ~30 seconds (15 cycles of 1s on, 1s off)
      Vibration.vibrate(
        pattern: List.generate(30, (i) => 1000), 
        repeat: 0,
      );
      
      // Auto-stop after 30s
      Timer(const Duration(seconds: 30), () {
        if (_isVibrating) dismissAlert();
      });
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
      notifyListeners();
      final response = await http.post(
        Uri.parse('$_baseUrl/cases'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'advocate_name': advocateName,
          'court_no': courtNo,
          'case_number': caseNumber,
          'item_no': itemNo,
          'alert_at': alertAt,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _trackedCases.add(CourtCase.fromJson(json.decode(response.body)));
        notifyListeners();
        fetchLiveStatus();
        return true;
      } else {
        _connectionError = "Server error: ${response.statusCode}";
        notifyListeners();
        return false;
      }
    } catch (e) {
      _connectionError = "Add error: $e";
      debugPrint('Add case error: $e');
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
      Map<String, String> queryParams = {};
      if (advocateName != null) queryParams['advocate_name'] = advocateName;
      if (courtNo != null) queryParams['court_no'] = courtNo;
      if (caseNumber != null) queryParams['case_number'] = caseNumber;
      if (itemNo != null) queryParams['item_no'] = itemNo;
      if (alertAt != null) queryParams['alert_at'] = alertAt;

      final uri = Uri.parse('$_baseUrl/cases/$id').replace(queryParameters: queryParams);
      final response = await http.patch(
        uri,
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final updatedCaseData = json.decode(response.body);
        final index = _trackedCases.indexWhere((element) => element.id == id);
        if (index != -1) {
          _trackedCases[index] = CourtCase.fromJson(updatedCaseData);
          notifyListeners();
          fetchLiveStatus();
        }
      }
    } catch (e) {
      _connectionError = "Update failed: $e";
      notifyListeners();
    }
  }

  Future<void> removeCase(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/cases/$id'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        _trackedCases.removeWhere((element) => element.id == id);
        notifyListeners();
      }
    } catch (e) {
      _connectionError = "Delete failed: $e";
      notifyListeners();
    }
  }

  Future<void> clearAllCases() async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/cases'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        _trackedCases.clear();
        notifyListeners();
      }
    } catch (e) {
      _connectionError = "Clear failed: $e";
      notifyListeners();
    }
  }

  Future<void> acknowledgeAlert(int id) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/cases/$id/acknowledge'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final index = _trackedCases.indexWhere((element) => element.id == id);
        if (index != -1) {
          _trackedCases[index].alertSent = true;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error acknowledging alert: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
