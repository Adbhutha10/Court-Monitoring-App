import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monitoring_provider.dart';
import '../models/court_case.dart';
import '../constants.dart';

class StatusDisplayScreen extends StatefulWidget {
  const StatusDisplayScreen({super.key});

  @override
  State<StatusDisplayScreen> createState() => _StatusDisplayScreenState();
}

class _StatusDisplayScreenState extends State<StatusDisplayScreen> {
  final _caseNoController = TextEditingController();
  final _itemNoController = TextEditingController();
  final _alertAtController = TextEditingController();
  final _advController = TextEditingController();
  
  String? _selectedCourt;
  bool _isAdding = false;

  final List<String> _courts = courtList;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitoringProvider>().fetchTrackedCases();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildClassicHeader(),
            _buildBrandingBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Consumer<MonitoringProvider>(
                        builder: (context, provider, child) {
                          if (provider.connectionError != null) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      provider.connectionError!,
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.settings, color: Colors.red),
                                    onPressed: _showUrlDialog,
                                    tooltip: 'Update Backend URL',
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const Text(
                        'Enter your case list',
                        style: TextStyle(
                          color: Color(0xFF0D328C),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Consumer<MonitoringProvider>(
                              builder: (context, provider, child) => _buildInputGroup(
                                'S.No.',
                                _buildReadOnlyField((provider.trackedCases.length + 1).toString()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _buildInputGroup('ADV', _buildClassicTextField(_advController)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInputGroup(
                        'Court',
                        _buildClassicDropdown(
                          'Select Court',
                          _courts,
                          _selectedCourt,
                          (val) => setState(() => _selectedCourt = val),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInputGroup('Case number', _buildClassicTextField(_caseNoController)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputGroup('Item no', _buildClassicTextField(_itemNoController)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputGroup('Alert at', _buildClassicTextField(_alertAtController)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _isAdding 
                        ? const Center(child: CircularProgressIndicator())
                        : _buildMainButton('ADD CASE', const Color(0xFF1947D1), _submitAdd),
                      const SizedBox(height: 20),
                      _buildCasesListArea(),
                      const SizedBox(height: 20),
                      _buildMainButton('Clear All', const Color(0xFFD10000), () {
                        context.read<MonitoringProvider>().clearAllCases();
                      }),
                      const SizedBox(height: 12),
                      _buildMainButton('GO', const Color(0xFF008033), () {
                        if (context.read<MonitoringProvider>().trackedCases.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Add at least one case first')),
                          );
                          return;
                        }
                        // Navigate to Live Status Display
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LiveStatusDisplayScreen()),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUrlDialog() {
    final provider = context.read<MonitoringProvider>();
    final controller = TextEditingController(text: provider.baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Backend'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Ngrok URL'),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => provider.testVibration(),
                child: const Text('TEST VIBRATION', style: TextStyle(color: Colors.orange)),
              ),
              TextButton(
                onPressed: () => provider.dismissAlert(),
                child: const Text('STOP VIBRATION', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          const Divider(),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              provider.setBaseUrl(controller.text);
              Navigator.pop(context);
            },
            child: const Text('CONNECT'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1947D1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Telangana High Court',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Live Case Status',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Column(
        children: [
          Text(
            'Developed by',
            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          Text(
            'AJTRS Foundation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D328C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputGroup(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF333333)),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      height: 40,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  Widget _buildClassicTextField(TextEditingController controller) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildClassicDropdown(String hint, List<String> items, String? value, Function(String?) onChanged) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMainButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCasesListArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cases List',
          style: TextStyle(
            color: Color(0xFF0D328C),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF1947D1), width: 1.5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Consumer<MonitoringProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.trackedCases.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (provider.trackedCases.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No cases added yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.trackedCases.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final c = provider.trackedCases[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1} - ${c.advocateName} : ${c.courtNo} : ${c.itemNo} : ${c.alertAt} : ${c.caseNumber}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => provider.removeCase(c.id),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _submitAdd() async {
    if (_caseNoController.text.isNotEmpty && _selectedCourt != null) {
      setState(() => _isAdding = true);
      
      final success = await context.read<MonitoringProvider>().addCase(
        _advController.text.isEmpty ? 'N/A' : _advController.text,
        _selectedCourt!,
        _caseNoController.text,
        _itemNoController.text,
        _alertAtController.text,
      );

      if (success) {
        _caseNoController.clear();
        _itemNoController.clear();
        _alertAtController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case added successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add case. Check connection/URL.')),
        );
      }
      
      setState(() => _isAdding = false);
    }
  }
}

class LiveStatusDisplayScreen extends StatefulWidget {
  const LiveStatusDisplayScreen({super.key});

  @override
  State<LiveStatusDisplayScreen> createState() => _LiveStatusDisplayScreenState();
}


class _LiveStatusDisplayScreenState extends State<LiveStatusDisplayScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildLiveHeader(),
            _buildBrandingBar(),
            Expanded(
              child: Consumer<MonitoringProvider>(
                builder: (context, provider, child) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '— Cases - Status Display —',
                          style: TextStyle(
                            color: Color(0xFF0D328C),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFF1947D1), width: 1.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: provider.trackedCases.length,
                              separatorBuilder: (context, index) => const Divider(height: 20),
                              itemBuilder: (context, index) {
                                final c = provider.trackedCases[index];
                                Color textColor = Colors.black;
                                
                                if (c.status == CaseStatus.immediate) {
                                  textColor = Colors.red;
                                } else if (c.status == CaseStatus.approaching) {
                                  textColor = Colors.green;
                                } else if (c.status == CaseStatus.far) {
                                  textColor = Colors.blue.shade900;
                                }

                                return Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        '${index + 1}-${c.courtNo}',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        c.itemNo,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        "R:${c.currentRunningPosition ?? 'NS'}",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildMainButton('BACK', const Color(0xFF1947D1), () => Navigator.pop(context)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1947D1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Telangana High Court',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Live Case Status Tracker',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          Consumer<MonitoringProvider>(
            builder: (context, provider, child) => Text(
              provider.lastUpdated != null 
                ? 'Sync: ${provider.lastUpdated!.hour}:${provider.lastUpdated!.minute.toString().padLeft(2, '0')}'
                : 'Syncing...',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Column(
        children: [
          Text(
            'Developed by',
            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          Text(
            'AJTRS Foundation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D328C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

