import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'services/custom_heatmap.dart';
import 'services/location_service.dart';
import 'services/auth_service.dart';
import 'widgets/barralateral.dart';
import 'widgets/LeyendaMapa.dart';
import 'widgets/alternar_boton.dart';
import 'widgets/botonEmergencia.dart';
import 'screenRutaSegura.dart';

class ScreenPrincipal extends StatefulWidget {
  const ScreenPrincipal({super.key});

  @override
  State<ScreenPrincipal> createState() => _ScreenPrincipalState();
}

class _ScreenPrincipalState extends State<ScreenPrincipal> {
  GoogleMapController? _mapController;
  bool _isLeyendaVisible = false;

  Set<TileOverlay> _tileOverlays = {};
  bool _isLoadingReportData = true;
  List<ReportPoint> _allReportPoints = [];

  // Servicios
  final LocationService _locationService = LocationService();
  // Eliminar estas líneas:
  //final FirebaseAuth _auth = FirebaseAuth.instance;
  //final GoogleSignIn _googleSignIn = GoogleSignIn();

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-18.0146, -70.2534),
    zoom: 13.0,
  );

  @override
  void initState() {
    super.initState();
    _fetchAllReportPoints();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchAllReportPoints() async {
    if (!mounted) return;
    setState(() {
      _isLoadingReportData = true;
      _allReportPoints = [];
      _tileOverlays = {};
    });

    try {
      QuerySnapshot reportSnapshot =
          await FirebaseFirestore.instance.collection('Reportes').get();

      List<ReportPoint> tempData = [];
      for (var doc in reportSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('ubicacion')) {
          final ubicacion = data['ubicacion'] as Map<String, dynamic>?;
          if (ubicacion != null &&
              ubicacion.containsKey('latitud') &&
              ubicacion.containsKey('longitud')) {
            final double? lat = (ubicacion['latitud'] as num?)?.toDouble();
            final double? lng = (ubicacion['longitud'] as num?)?.toDouble();

            if (lat != null && lng != null) {
              tempData.add(ReportPoint(LatLng(lat, lng)));
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _allReportPoints = tempData;
          _isLoadingReportData = false;
        });
        _updateTileOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReportData = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar datos de reportes: $e')),
          );
        }
      }
    }
  }

  void _updateTileOverlay() {
    if (!mounted) return;
    
    if (_allReportPoints.isEmpty && !_isLoadingReportData) {
      if (mounted) {
        setState(() {
          _tileOverlays = {};
        });
      }
      return;
    }
    if (_allReportPoints.isNotEmpty) {
      final heatmapTileProvider = CustomHeatmapTileProvider(
        allReportPoints: _allReportPoints,
        radiusPixels: 40,
        gradientColors: const [
          Color.fromARGB(0, 0, 0, 255),
          Color.fromARGB(100, 0, 255, 255),
          Color.fromARGB(120, 0, 255, 0),
          Color.fromARGB(150, 255, 255, 0),
          Color.fromARGB(180, 255, 0, 0),
        ],
        gradientStops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      );

      final TileOverlay heatmapOverlay = TileOverlay(
        tileOverlayId: const TileOverlayId('heatmap_overlay'),
        tileProvider: heatmapTileProvider,
        fadeIn: true,
        transparency: 0.0,
      );
      if(mounted){
        setState(() {
          _tileOverlays = {heatmapOverlay};
        });
      }
    }
    _mapController?.animateCamera(CameraUpdate.zoomBy(0.000001));
  }

  void _toggleLeyenda() {
    if (!mounted) return;
    setState(() {
      _isLeyendaVisible = !_isLeyendaVisible;
    });
  }

  void _closeLeyenda() {
    if (!mounted) return;
    setState(() {
      _isLeyendaVisible = false;
    });
  }

  Future<void> _handleLogout() async {
    if (!mounted) return;

    // Mostrar diálogo de confirmación
    bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Cerrar Sesión'),
            ],
          ),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      try {
        // Mostrar indicador de carga
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Detener servicios
        _locationService.stopLocationTracking();

        // Cerrar sesión usando AuthService
        await AuthService.signOut();

        if (mounted) {
          // Cerrar el diálogo de carga
          Navigator.of(context).pop();

          // Navegar a la pantalla de login y limpiar el stack
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          // Cerrar el diálogo de carga si está abierto
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesión: $e'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _refreshData() {
    _fetchAllReportPoints();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BarraLateral(onLogout: _handleLogout),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _kInitialPosition,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              if (!_isLoadingReportData) {
                _updateTileOverlay();
              }
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            tileOverlays: _tileOverlays,
          ),
          if (_isLoadingReportData)
            const Center(child: CircularProgressIndicator()),
          
          Positioned(
            top: 40,
            left: 20,
            child: SafeArea(
              child: Builder(
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.menu),
                    color: Colors.black54,
                    tooltip: 'Abrir menú',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  color: Colors.black54,
                  tooltip: 'Leyenda del mapa',
                  onPressed: _toggleLeyenda,
                ),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  color: Colors.black54,
                  tooltip: 'Refrescar datos',
                  onPressed: _refreshData,
                ),
              ),
            ),
          ),
          Positioned(
            top: 100,
            right: 20,
            child: SafeArea(
              child: AlternarBoton(
                onPressed: () {
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const ScreenRutaSegura()),
                    );
                  }
                },
                tooltip: 'Ver pantalla de Ruta Segura',
              ),
            ),
          ),
          Positioned( 
            bottom: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _zoomIn,
                      tooltip: 'Zoom in',
                    ),
                    const Divider(height: 1, indent: 4, endIndent: 4),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _zoomOut,
                      tooltip: 'Zoom out',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned( 
            bottom: 20,
            left: 20, 
            child: SafeArea(child: EmergencyButton()),
          ),
          Positioned(
            bottom: 80,
            left: 20,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Reportes: ${_allReportPoints.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          if (_isLeyendaVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeLeyenda,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: LeyendaMapa(
                      onClose: _closeLeyenda,
                      tipo: LeyendaTipo.principal, 
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
