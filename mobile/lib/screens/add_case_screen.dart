import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monitoring_provider.dart';
import '../constants.dart';

class AddCaseScreen extends StatefulWidget {
  const AddCaseScreen({super.key});

  @override
  State<AddCaseScreen> createState() => _AddCaseScreenState();
}

class _AddCaseScreenState extends State<AddCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  String _advName = 'CS';
  String _courtNo = courtList.first;
  final _caseNoController = TextEditingController();
  final _itemNoController = TextEditingController();
  final _alertAtController = TextEditingController();

  final List<String> _advocates = ['CS', 'BNK', 'MSC', 'BP', 'PM', 'Amr', 'RH'];
  final List<String> _courts = courtList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Case to Track')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Advocate Initials (2-3 chars)',
                  hintText: 'e.g., CS or BNK',
                  counterText: "",
                ),
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
                onChanged: (val) => _advName = val.toUpperCase(),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter initials';
                  if (val.length < 2) return 'Min 2 characters';
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _courtNo,
                decoration: const InputDecoration(labelText: 'Court'),
                items: _courts.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _courtNo = val!),
              ),
              TextFormField(
                controller: _caseNoController,
                decoration: const InputDecoration(labelText: 'Case Number (e.g., WA1044/24)'),
                validator: (val) => val!.isEmpty ? 'Enter case number' : null,
              ),
              TextFormField(
                controller: _itemNoController,
                decoration: const InputDecoration(labelText: 'Item No (P)'),
                validator: (val) => val!.isEmpty ? 'Enter item number' : null,
              ),
              TextFormField(
                controller: _alertAtController,
                decoration: const InputDecoration(labelText: 'Alert At (A)'),
                validator: (val) => val!.isEmpty ? 'Enter alert threshold' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('ADD CASE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<MonitoringProvider>().addCase(
        _advName,
        _courtNo,
        _caseNoController.text,
        _itemNoController.text,
        _alertAtController.text,
      );
      Navigator.pop(context);
    }
  }
}
