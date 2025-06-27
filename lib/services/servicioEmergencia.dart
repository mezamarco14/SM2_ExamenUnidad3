import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyService {
  // Singleton pattern
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal() {
    _loadContacts();
  }

  final Map<String, IconData> iconMap = {
    'support_agent': Icons.support_agent,
    'local_police': Icons.local_police,
    'medical_services': Icons.medical_services,
    'directions_car': Icons.directions_car,
    'coronavirus': Icons.coronavirus,
    'security': Icons.security,
    'local_fire_department': Icons.local_fire_department,
    'emergency': Icons.emergency,
    'voicemail': Icons.voicemail,
    'local_hospital': Icons.local_hospital,
    'verified_user': Icons.verified_user,
    'person': Icons.person,
  };

  IconData getIconFromName(String name) {
    return iconMap[name] ?? Icons.help_outline;
  }

  final List<Map<String, dynamic>> _emergencyContacts = [
    {
      'id': 1,
      'name': 'Violencia familiar y sexual (MIMP)',
      'phone': '100',
      'iconName': 'support_agent',
      'isPersonal': false
    },
    {
      'id': 2,
      'name': 'Policía Nacional del Perú',
      'phone': '105',
      'iconName': 'local_police',
      'isPersonal': false
    },
    {
      'id': 3,
      'name': 'SAMU - Atención Médica Móvil',
      'phone': '106',
      'iconName': 'medical_services',
      'isPersonal': false
    },
    {
      'id': 4,
      'name': 'Policía de Carreteras',
      'phone': '110',
      'iconName': 'directions_car',
      'isPersonal': false
    },
    {
      'id': 5,
      'name': 'MINSA - Consultas sobre Coronavirus',
      'phone': '113',
      'iconName': 'coronavirus',
      'isPersonal': false
    },
    {
      'id': 6,
      'name': 'Defensa Civil',
      'phone': '115',
      'iconName': 'security',
      'isPersonal': false
    },
    {
      'id': 7,
      'name': 'Bomberos Voluntarios del Perú',
      'phone': '116',
      'iconName': 'local_fire_department',
      'isPersonal': false
    },
    {
      'id': 8,
      'name': 'EsSalud - Atención Médica Móvil',
      'phone': '117',
      'iconName': 'emergency',
      'isPersonal': false
    },
    {
      'id': 9,
      'name': 'MTC - Mensajes de voz ante emergencias',
      'phone': '119',
      'iconName': 'voicemail',
      'isPersonal': false
    },
    {
      'id': 10,
      'name': 'Hospital Hipólito Unanue',
      'phone': '(052) 242121',
      'iconName': 'local_hospital',
      'isPersonal': false
    },
    {
      'id': 11,
      'name': 'Seguridad Ciudadana – MPT',
      'phone': '(052) 580310',
      'iconName': 'verified_user',
      'isPersonal': false
    },
    {
      'id': 12,
      'name': 'Ricardo (Contacto Personal)',
      'phone': '961256178',
      'iconName': 'person',
      'isPersonal': true
    },
  ];

  late int nextId = _calculateNextId();

  int _calculateNextId() {
    if (_emergencyContacts.isEmpty) return 1;
    final maxId =
        _emergencyContacts.map((contact) => contact['id'] as int).reduce(max);
    return maxId + 1;
  }

  List<Map<String, dynamic>> getEmergencyContacts({bool copy = true}) {
    return copy ? List.from(_emergencyContacts) : _emergencyContacts;
  }

  void deleteEmergencyContactById(int id) {
    final index =
        _emergencyContacts.indexWhere((contact) => contact['id'] == id);
    if (index != -1) {
      _emergencyContacts.removeAt(index);
    }
    nextId = _calculateNextId();
    _saveContacts();
  }

  void updateEmergencyContact({
    required int id,
    required String name,
    required String phone,
    required String iconName,
    required bool isPersonal,
  }) {
    final contact = _emergencyContacts.firstWhere((c) => c['id'] == id);
    contact['name'] = name;
    contact['phone'] = phone;
    contact['iconName'] = iconName;
    contact['isPersonal'] = isPersonal;
    _saveContacts();
  }

  void addEmergencyContact({
    required String name,
    required String phone,
    String iconName = 'person',
    bool isPersonal = true,
  }) {
    _emergencyContacts.add({
      'id': nextId,
      'name': name,
      'phone': phone,
      'iconName': iconName,
      'isPersonal': isPersonal,
    });
    nextId++;
    _saveContacts();
  }

  void reorderEmergencyContact(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final contact = _emergencyContacts.removeAt(oldIndex);
    _emergencyContacts.insert(newIndex, contact);
    _updateBackendOrder();
    _saveContacts();
  }

  void _updateBackendOrder() async {
    final List orderedIds = _emergencyContacts.map((c) => c['id']).toList();
    // API para guardar el nuevo orden
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_contacts', jsonEncode(_emergencyContacts));
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('emergency_contacts');
    if (jsonString != null) {
      List<dynamic> loadedList = jsonDecode(jsonString);
      _emergencyContacts.clear();
      for (var item in loadedList) {
        _emergencyContacts.add({
          'id': item['id'],
          'name': item['name'],
          'phone': item['phone'],
          'iconName': item['iconName'],
          'isPersonal': item['isPersonal'],
        });
      }
      nextId = _calculateNextId();
    }
  }
}
