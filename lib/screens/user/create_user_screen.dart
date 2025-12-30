import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/arrays.dart';
import 'package:elegant_notification/resources/stacked_options.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/age_utils.dart';
import '../../utils/department_utils.dart';

// yyyy-MM-dd 형식으로 자동 하이픈을 추가하는 포매터
class BirthDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length > 10) {
      return oldValue;
    }

    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    var buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i == 3 || i == 5) && i != text.length - 1) {
        buffer.write('-');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

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

  // 상태 변수로 소속과 기수를 관리
  String? _department;
  String _classYear = '';

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
    String newClassYear = '';
    String? newDepartment;

    // 날짜가 형식에 맞게 모두 입력되었을 때만 계산
    if (birthDate.length == 10 && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birthDate)) {
      newClassYear = AgeCalculator.calculateClassYear(birthDate);
      final calculatedDepartment = DepartmentCalculator.calculateDepartment(birthDate);
      if (calculatedDepartment.isNotEmpty && _departments.contains(calculatedDepartment)) {
        newDepartment = calculatedDepartment;
      }
    }

    // setState를 호출하여 UI를 갱신
    setState(() {
      _classYear = newClassYear;
      _department = newDepartment;
    });
  }

  Future<void> _loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneController.text = prefs.getString('savedPhoneNumber') ?? '';
    });
  }

  Future<void> _submit() async {
    // Form의 validator들을 먼저 실행
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 소속과 기수가 비어있는지 수동으로 검사
    if (_department == null || _classYear.isEmpty) {
      ElegantNotification.error(
        title: const Text('오류'),
        description: const Text('생년월일을 형식에 맞게 입력하여 소속과 기수를 확인해주세요.'),
        animation: AnimationType.fromTop,
        position: Alignment.topCenter,
      ).show(context);
      return;
    }

    try {
      // 수정: 'department' 필드 저장 로직 제거
      await FirebaseFirestore.instance
          .collection('users')
          .add({ 
        'name': _nameController.text,
        'phoneNumber': _phoneController.text, 
        'birthDate': _birthDateController.text,
        // 'department': _department, // 이 필드는 더 이상 저장하지 않음
        'classYear': _classYear,
        'permissionLevel': 4, 
      });

      if (mounted) {
        ElegantNotification.success(
          title: const Text('성공'),
          description: const Text('성공적으로 등록되었습니다. 관리자의 승인을 기다려주세요.'),
          animation: AnimationType.fromTop,
          position: Alignment.topCenter,
        ).show(context);

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/mainRoot',
          (route) => false,
          arguments: _phoneController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        ElegantNotification.error(
          title: const Text('오류'),
          description: Text('등록 중 오류가 발생했습니다: $e'),
          animation: AnimationType.fromTop,
          position: Alignment.topCenter,
        ).show(context);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  decoration: const InputDecoration(
                    labelText: '생년월일 (예: 1990-01-01)',
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [BirthDateInputFormatter()],
                  maxLength: 10,
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

                // '소속'을 라벨로 변경
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '소속 (생년월일 입력 시 자동 입력)',
                    contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  child: Text(
                    _department ?? '\u200B', // 값이 없을 때 높이 유지를 위해 보이지 않는 공백 추가
                    style: const TextStyle(fontSize: 16),
                  ),
                ),

                // '기수'를 라벨로 변경
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '기수 (생년월일 입력 시 자동 입력)',
                    contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  child: Text(
                    _classYear.isNotEmpty ? _classYear : '\u200B',
                    style: const TextStyle(fontSize: 16),
                  ),
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
