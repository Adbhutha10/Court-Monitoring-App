import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'dart:typed_data';

import 'helpers/database_helper.dart';
import 'models/court_case.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'background_service_channel',
    'Background Service Channel',
    description: 'Used for background case monitoring',
    importance: Importance.low,
  );

  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'court_alerts',
    'Court Alerts',
    description: 'Notifications for court case updates',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
      
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(alertChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'background_service_channel',
      initialNotificationTitle: 'BenchAlert Active',
      initialNotificationContent: 'Monitoring for court updates...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Initialize notifications for background isolate
  const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('stopAlertVibration').listen((event) {
    Vibration.cancel();
  });

  // Railway Production: https://court-monitoring-app-production.up.railway.app
  String _baseUrl = 'https://court-monitoring-app-production.up.railway.app';
  service.on('updateConfig').listen((event) {
    if (event != null && event['baseUrl'] != null) {
      _baseUrl = event['baseUrl'];
    }
  });

  // Polling loop
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    DateTime now = DateTime.now();
    String timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "BenchAlert Monitoring Active",
        content: "Last checked at $timeStr",
      );
    }

    try {
      final dbHelper = DatabaseHelper();
      final cases = await dbHelper.getCases();
      
      if (cases.isEmpty) {
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "BenchAlert Idle",
            content: "No cases tracked. Add a case to monitor.",
          );
        }
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/live-status'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> liveData = json.decode(response.body);
        
        for (var caseItem in cases) {
          final courtData = liveData.firstWhere(
            (element) => element['court_no'] == caseItem.courtNo,
            orElse: () => null,
          );

          if (courtData != null) {
            String newPos = courtData['running_position'].toString();
            
            // Check Alerts
            int? currentPos = int.tryParse(newPos);
            int? alertAtPos = int.tryParse(caseItem.alertAt);

            if (currentPos != null && alertAtPos != null && currentPos >= alertAtPos && !caseItem.customAlertSent) {
               // Update updatedAt locally for transparency
               caseItem.updatedAt = courtData['updated_at'] != null ? DateTime.tryParse(courtData['updated_at']) : null;
               caseItem.customAlertSent = true;
              await _triggerAlertBackground(caseItem, flutterLocalNotificationsPlugin, "ALERT: Board reached ${caseItem.alertAt}!");
              await dbHelper.updateCase(caseItem);
            }

            if (caseItem.status == CaseStatus.immediate && !caseItem.alertSent) {
              caseItem.alertSent = true;
              await _triggerAlertBackground(caseItem, flutterLocalNotificationsPlugin, "CASE REACHED RED STATUS!");
              await dbHelper.updateCase(caseItem);
            }

            // Auto-removal: Case passed (2+ items)
            if (currentPos != null && int.tryParse(caseItem.itemNo) != null) {
              int p = int.tryParse(caseItem.itemNo)!;
              if (p - currentPos < -2) {
                await dbHelper.deleteCase(caseItem.id);
              }
            }
          }
        }
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "BenchAlert Status",
            content: "[T: $timeStr] Sync: OK (${cases.length} cases)",
          );
        }
      } else {
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "BenchAlert Status",
            content: "[T: $timeStr] URL ERR: ${response.statusCode}",
          );
        }
      }
    } catch (e) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "BenchAlert Status",
          content: "[T: $timeStr] EXCEPTION: $e",
        );
      }
    }
  });
}

Future<void> _triggerAlertBackground(CourtCase caseItem, FlutterLocalNotificationsPlugin notifications, String title) async {
  // Trigger notification
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
  
  await notifications.show(
    caseItem.id,
    title,
    'Court ${caseItem.courtNo}: Case ${caseItem.caseNumber} is live!',
    NotificationDetails(android: androidDetails),
  );

  // Trigger persistent vibration if possible in background context
  if (await Vibration.hasVibrator() == true) {
    Vibration.vibrate(
      pattern: [0, 1000, 500, 1000, 500, 1000, 500, 1000],
      repeat: 0,
    );
  }
}
