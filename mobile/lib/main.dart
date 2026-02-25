import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/monitoring_provider.dart';
import 'screens/status_display_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MonitoringProvider()),
      ],
      child: const CourtMonitoringApp(),
    ),
  );
}

class CourtMonitoringApp extends StatelessWidget {
  const CourtMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Court Monitoring App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            const GlobalAlertWatcher(),
          ],
        );
      },
      home: const StatusDisplayScreen(),
    );
  }
}

class GlobalAlertWatcher extends StatelessWidget {
  const GlobalAlertWatcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitoringProvider>(
      builder: (context, provider, child) {
        if (provider.activeAlertCase == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'CASE REACHED!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Court: ${provider.activeAlertCase!.courtNo}\nCase: ${provider.activeAlertCase!.caseNumber}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => provider.dismissAlert(),
                      child: const Text(
                        'ACKNOWLEDGE',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
