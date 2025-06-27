import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:math'; // Para Random

class FakeReportMapScreen extends StatefulWidget {
  const FakeReportMapScreen({super.key});

  @override
  State<FakeReportMapScreen> createState() => _FakeReportMapScreenState();
}

class _FakeReportMapScreenState extends State<FakeReportMapScreen> {
  GoogleMapController? _mapController;
  int _reportCounter = 1;
  bool _isSubmitting = false;
  Set<Marker> _markers = {};

  // Definiciones de categorías y niveles de riesgo
  final List<Map<String, dynamic>> _allCategories = [
    {'id': 'accident', 'name': 'Accidente', 'icon': Icons.car_crash, 'color': Colors.red},
    {'id': 'fire', 'name': 'Incendio', 'icon': Icons.local_fire_department, 'color': Colors.orange},
    {'id': 'roadblock', 'name': 'Vía bloqueada', 'icon': Icons.block, 'color': Colors.amber},
    {'id': 'protest', 'name': 'Manifestación', 'icon': Icons.people, 'color': Colors.yellow.shade700},
    {'id': 'theft', 'name': 'Robo', 'icon': Icons.money_off, 'color': Colors.purple},
    {'id': 'assault', 'name': 'Asalto', 'icon': Icons.personal_injury, 'color': Colors.deepPurple},
    {'id': 'violence', 'name': 'Violencia', 'icon': Icons.front_hand, 'color': Colors.red.shade800},
    {'id': 'vandalism', 'name': 'Vandalismo', 'icon': Icons.broken_image, 'color': Colors.brown},
  ];

  final List<String> _riskLevelOptions = ['Bajo', 'Medio', 'Alto'];

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-18.0146, -70.2534), // Coordenadas de Tacna
    zoom: 13.0,
  );

  Future<void> _handleMapTap(LatLng position) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _markers = {
        Marker(
          markerId: MarkerId(position.toString()),
          position: position,
          infoWindow: const InfoWindow(title: 'Generando reporte...'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        )
      };
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final String reportTitle = "ReporteTest$_reportCounter";
      
      // Seleccionar tipo aleatorio
      final randomCategory = _allCategories[Random().nextInt(_allCategories.length)];
      final String selectedCategoryType = randomCategory['id'];
      final String selectedCategoryName = randomCategory['name'];

      // Seleccionar nivel de riesgo aleatorio
      final String randomRiskLevel = _riskLevelOptions[Random().nextInt(_riskLevelOptions.length)];

      final reporteData = {
        'id': const Uuid().v4(),
        'tipo': selectedCategoryType,
        'titulo': reportTitle,
        'descripcion': 'Reporte de prueba: $selectedCategoryName generado automáticamente desde el mapa para testing de alertas de proximidad.',
        'nivelRiesgo': randomRiskLevel,
        'ubicacion': {
          'latitud': position.latitude,
          'longitud': position.longitude
        },
        'imagenes': [],
        'fechaCreacion': FieldValue.serverTimestamp(),
        'fechaCreacionLocal': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'estado': 'Activo',
        'etapa': 'pendiente',
        'esReportePrueba': true, // Marcador para identificar reportes de prueba
      };

      await FirebaseFirestore.instance.collection('Reportes').add(reporteData);

      setState(() {
        _reportCounter++;
        _isSubmitting = false;
        _markers = {
          Marker(
            markerId: MarkerId(position.toString()),
            position: position,
            infoWindow: InfoWindow(
              title: '$reportTitle ✅',
              snippet: '$selectedCategoryName - $randomRiskLevel\nLat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}'
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          )
        };
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                randomCategory['icon'],
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$reportTitle creado: $selectedCategoryName ($randomRiskLevel)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _markers = {
            Marker(
              markerId: MarkerId(position.toString()),
              position: position,
              infoWindow: const InfoWindow(title: 'Error al enviar ❌'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            )
          };
        });
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error al enviar el reporte: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _clearTestReports() async {
    try {
      QuerySnapshot testReports = await FirebaseFirestore.instance
          .collection('Reportes')
          .where('esReportePrueba', isEqualTo: true)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      for (QueryDocumentSnapshot doc in testReports.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      setState(() {
        _markers.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${testReports.docs.length} reportes de prueba eliminados'),
            backgroundColor: Colors.blue.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error eliminando reportes: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('Instrucciones de Testing'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🗺️ Toca cualquier punto del mapa para crear un reporte de prueba',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Text('El reporte se creará con:'),
            const SizedBox(height: 8),
            const Text('• Tipo aleatorio (robo, incendio, etc.)'),
            const Text('• Nivel de riesgo aleatorio'),
            const Text('• Ubicación donde tocaste'),
            const Text('• Marcado como reporte de prueba'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Asegúrate de que el servidor Python esté ejecutándose para recibir alertas.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Reportes de Prueba'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: _clearTestReports,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Limpiar reportes de prueba',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _kInitialPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onTap: _handleMapTap,
            markers: _markers,
            zoomControlsEnabled: true,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            mapType: MapType.normal,
          ),
          
          // Panel de información superior
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.touch_app,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Toca el mapa para crear reportes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Reportes creados: ${_reportCounter - 1}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "help",
            onPressed: _showInstructions,
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            child: const Icon(Icons.help_outline),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: "clear",
            onPressed: _clearTestReports,
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Limpiar'),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
