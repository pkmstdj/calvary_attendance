import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/age_utils.dart';
import '../../utils/department_utils.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _classYearController = TextEditingController();
  String? _department;
  // 소속 목록 수정: '청년X부' -> 'X청'
  final List<String> _departments = [
    '영아부', '유치부', '유년부', '초등부', '중등부', '고등부',
    '1청', '2청', '3청', '4청', '신혼부부', '장년'
  ];

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
    _birthDateController.addListener(_updateClassYearAndDepartment);
  }

  void _updateClassYearAndDepartment() {
    final birthDate = _birthDateController.text;
    if (birthDate.length >= 4) {
      final classYear = AgeCalculator.calculateClassYear(birthDate);
      final department = DepartmentCalculator.calculateDepartment(birthDate);

      _classYearController.text = classYear;

      if (department.isNotEmpty && _departments.contains(department)) {
        setState(() {
          _department = department;
        });
      }
    }
  }

  Future<void> _loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneController.text = prefs.getString('savedPhoneNumber') ?? '';
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        await FirebaseFirestore.instance.collection('users').doc(_phoneController.text).set({
          'name': _nameController.text,
          'phone': _phoneController.text,
          'birthDate': _birthDateController.text,
          'department': _department,
          'classYear': _classYearController.text,
          'permissionLevel': null,
        });

        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('성공적으로 등록되었습니다. 관리자의 승인을 기다려주세요.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/root', (route) => false);
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('등록 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _classYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('성도 정보 등록'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '이름'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '이름을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: '전화번호'),
                  keyboardType: TextInputType.phone,
                  enabled: false,
                ),
                TextFormField(
                  controller: _birthDateController,
                  decoration: const InputDecoration(labelText: '생년월일 (예: 1990-01-01)'),
                  keyboardType: TextInputType.datetime,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '생년월일을 입력해주세요.';
                    }
                    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
                      return '형식(yyyy-MM-dd)에 맞게 입력해주세요.';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _department,
                  decoration: const InputDecoration(labelText: '소속 (생년월일 입력 시 자동 선택)'),
                  items: _departments.map((String department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Text(department),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _department = newValue;
                    });
                  },
                  validator: (value) => value == null ? '소속을 선택해주세요' : null,
                ),
                 TextFormField(
                  controller: _classYearController,
                  decoration: const InputDecoration(labelText: '기수 (생년월일 입력 시 자동 계산)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '기수를 입력해주세요 (생년월일 입력 시 자동계산)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('등록하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
