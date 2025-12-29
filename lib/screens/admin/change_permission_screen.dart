import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/user_utils.dart';

class ChangePermissionScreen extends StatefulWidget {
  final String targetPhoneNumber;
  final int viewerPermissionLevel;
  final int currentPermissionLevel;

  const ChangePermissionScreen({
    super.key,
    required this.targetPhoneNumber,
    required this.viewerPermissionLevel,
    required this.currentPermissionLevel,
  });

  @override
  State<ChangePermissionScreen> createState() => _ChangePermissionScreenState();
}

class _ChangePermissionScreenState extends State<ChangePermissionScreen> {
  int? _selectedPermission;

  @override
  void initState() {
    super.initState();
    _selectedPermission = widget.currentPermissionLevel;
  }

  @override
  Widget build(BuildContext context) {
    final availablePermissions = [0, 1, 2, 3, 4]
        .where((level) => level >= widget.viewerPermissionLevel)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('등급 변경'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: _selectedPermission,
              items: availablePermissions.map((level) {
                return DropdownMenuItem<int>(
                  value: level,
                  child: Text(getPermissionLabel(level)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPermission = value;
                });
              },
              decoration: const InputDecoration(
                labelText: '새로운 등급',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_selectedPermission == null) return;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.targetPhoneNumber)
                    .update({'permissionLevel': _selectedPermission});
                Navigator.pop(context);
              },
              child: const Text('저장'),
            )
          ],
        ),
      ),
    );
  }
}
