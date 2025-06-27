import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});
  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _notificacionesActivas = true;
  double _radioAlerta = 500.0;
  String _sensibilidad = 'Medio';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userEmail;
  String? _errorMessage;
  final List<String> _sensibilidadOptions = ['Bajo', 'Medio', 'Alto'];
  final Map<String, String> _sensibilidadDescriptions = {
    'Bajo': 'Solo reportes de alto riesgo',
    'Medio': 'Reportes de medio y alto riesgo',
    'Alto': 'Todos los reportes activos',
  };
  final Map<String, IconData> _sensibilidadIcons = {
    'Bajo': Icons.shield_outlined,
    'Medio': Icons.security,
    'Alto': Icons.warning_amber_outlined,
  };
  final Map<String, Color> _sensibilidadColors = {
    'Bajo': Colors.green,
    'Medio': Colors.orange,
    'Alto': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _loadDataForScreen();
  }

  Future<void> _loadDataForScreen() async {
    _userEmail = await AuthService.getCurrentUserEmail();
    if (_userEmail != null && _userEmail!.isNotEmpty) {
      await _loadUserConfig();
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudo identificar el usuario. Por favor, inicia sesion nuevamente.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserConfig() async {
    if (_userEmail == null || _userEmail!.isEmpty) {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('usuarios')
          .doc(_userEmail)
          .get();
      if (userDoc.exists && mounted) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _notificacionesActivas = userData['notificacionesActivas'] ?? true;
          _radioAlerta = (userData['radioAlerta'] ?? 500.0).toDouble();
          _sensibilidad = userData['sensibilidad'] ?? 'Medio';
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se encontro la configuracion del usuario para $_userEmail.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar configuracion para $_userEmail: $e';
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_userEmail == null || _userEmail!.isEmpty) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Usuario no identificado para guardar.'), backgroundColor: Colors.red),
        );
       }
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _firestore.collection('usuarios').doc(_userEmail).update({
        'notificacionesActivas': _notificacionesActivas,
        'radioAlerta': _radioAlerta.round(),
        'sensibilidad': _sensibilidad,
        'ultimaConfiguracion': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(_notificacionesActivas ? 'Configuracion guardada. Recibiras alertas en un radio de ${_formatDistance(_radioAlerta)}' : 'Configuracion guardada. Las alertas estan desactivadas'),),],),
            backgroundColor: Colors.green, duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red,),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.indigo.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight,), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade200),),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8),), child: Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24,),),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Alertas Inteligentes', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 16,),), const SizedBox(height: 4), Text('Recibe notificaciones automaticas cuando te acerques a reportes de riesgo en tu area.', style: TextStyle(color: Colors.blue.shade700, fontSize: 14,),),],),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red, duration: const Duration(seconds: 3),),);
            setState(() => _errorMessage = null);
        }
      });
    }
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuracion de Alertas'), backgroundColor: Colors.indigo[700], foregroundColor: Colors.white, elevation: 0,),
        body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Cargando configuracion...'),],),),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion de Alertas'), backgroundColor: Colors.indigo[700], foregroundColor: Colors.white, elevation: 0,
        actions: [if (_isSaving) const Padding(padding: EdgeInsets.only(right: 16.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white),),),),),],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.indigo[700]!, Colors.grey.shade50,], stops: const [0.0, 0.3],),),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildInfoCard(),
            Card(
              elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _notificacionesActivas ? Colors.green.shade100 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8),), child: Icon(_notificacionesActivas ? Icons.notifications_active : Icons.notifications_off, color: _notificacionesActivas ? Colors.green.shade700 : Colors.grey.shade600, size: 24,),),
                        const SizedBox(width: 16),
                        const Expanded(child: Text('Notificaciones de Riesgo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),),),
                        Switch(value: _notificacionesActivas, onChanged: (value) => setState(() => _notificacionesActivas = value), activeColor: Colors.indigo[700], materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _notificacionesActivas ? Colors.green.shade50 : Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _notificacionesActivas ? Colors.green.shade200 : Colors.grey.shade300,),), child: Text(_notificacionesActivas ? 'Recibiras alertas cuando te acerques a reportes de riesgo' : 'No recibiras notificaciones de proximidad', style: TextStyle(color: _notificacionesActivas ? Colors.green.shade700 : Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500,),),),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8),), child: Icon(Icons.radio_button_checked, color: Colors.blue.shade700, size: 24,),), const SizedBox(width: 16), const Text('Radio de Alerta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),),],),
                    const SizedBox(height: 20),
                    Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.indigo.shade200),), child: Text(_formatDistance(_radioAlerta), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo.shade700,),),),),
                    const SizedBox(height: 16),
                    SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: Colors.indigo[700], inactiveTrackColor: Colors.indigo[100], thumbColor: Colors.indigo[700], overlayColor: Colors.indigo[100], trackHeight: 6, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),), child: Slider(value: _radioAlerta, min: 100, max: 2000, divisions: 19, onChanged: (value) { if (_notificacionesActivas) setState(() => _radioAlerta = value); },),),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('100m', style: TextStyle(color: Colors.grey[600], fontSize: 12)), Text('2km', style: TextStyle(color: Colors.grey[600], fontSize: 12)),],),
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200),), child: Text('Recibiras alertas cuando estes a menos de ${_formatDistance(_radioAlerta)} de un reporte activo', style: TextStyle(color: Colors.blue.shade700, fontSize: 14,),),),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _sensibilidadColors[_sensibilidad]!.withOpacity(0.1), borderRadius: BorderRadius.circular(8),), child: Icon(_sensibilidadIcons[_sensibilidad], color: _sensibilidadColors[_sensibilidad], size: 24,),), const SizedBox(width: 16), const Text('Sensibilidad de Alertas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),),],),
                    const SizedBox(height: 20),
                    ...(_sensibilidadOptions.map((option) {
                      bool isSelected = option == _sensibilidad;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: isSelected ? _sensibilidadColors[option]!.withOpacity(0.1) : null, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? _sensibilidadColors[option]! : Colors.grey.shade300, width: isSelected ? 2 : 1,),),
                        child: RadioListTile<String>(title: Row(children: [Icon(_sensibilidadIcons[option], color: _sensibilidadColors[option], size: 20,), const SizedBox(width: 8), Text(option, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,),),],), subtitle: Text(_sensibilidadDescriptions[option]!, style: TextStyle(color: Colors.grey[600], fontSize: 13,),), value: option, groupValue: _sensibilidad, activeColor: _sensibilidadColors[option], onChanged: (value) { if (_notificacionesActivas) setState(() => _sensibilidad = value!); },),
                      );
                    }).toList()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity, height: 56,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigo[600]!, Colors.indigo[800]!],), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4),),],),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveConfig,
                icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white),),) : const Icon(Icons.save, color: Colors.white),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar Configuracion', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,),),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),),),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200),),
              child: Row(children: [Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20), const SizedBox(width: 12), Expanded(child: Text('Las notificaciones funcionan en segundo plano. Asegurate de tener los permisos de ubicacion activados.', style: TextStyle(color: Colors.amber.shade800, fontSize: 12,),),),],),
            ),
          ],
        ),
      ),
    );
  }
}