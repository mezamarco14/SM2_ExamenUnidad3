import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart' as g_places;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../widgets/barralateral.dart';
import '../widgets/alternar_boton.dart';
import '../widgets/botonEmergencia.dart';
import 'screen_principal.dart';
import '../widgets/LeyendaMapa.dart';

const String googleMapsApiKey = 'AIzaSyBl1LlKDZ_TslvGooMeecMRl6vrXH3cDRs';

enum TimeFilter { all, last24Hours, last12Hours, last1Hour }

String timeFilterToString(TimeFilter filter) {
  switch (filter) {
    case TimeFilter.all: return "Todos";
    case TimeFilter.last24Hours: return "Últimas 24h";
    case TimeFilter.last12Hours: return "Últimas 12h";
    case TimeFilter.last1Hour: return "Última 1h";
  }
}

class ScreenRutaSegura extends StatefulWidget {
  const ScreenRutaSegura({super.key});

  @override
  State<ScreenRutaSegura> createState() => _ScreenRutaSeguraState();
}

class PolylineData {
  final List<LatLng> coordinates;
  final Color color;
  final String polylineId;
  final double zIndex;
  final String? distanceText;
  final String? durationText;
  final bool isDetour;

  PolylineData({
    required this.coordinates,
    required this.color,
    required this.polylineId,
    required this.zIndex,
    this.distanceText,
    this.durationText,
    this.isDetour = false,
  });
}

enum RouteType { normal, safe }

class _ScreenRutaSeguraState extends State<ScreenRutaSegura> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final TextEditingController origenController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();

  final g_places.GoogleMapsPlaces _places = g_places.GoogleMapsPlaces(apiKey: googleMapsApiKey);

  static const CameraPosition _kInitialPosition = CameraPosition(target: LatLng(-18.0146, -70.2534), zoom: 13.0);

  final Set<Polyline> _polylines = {};
  List<g_places.Prediction> _placeSuggestions = [];
  bool _isFetchingSuggestions = false;
  bool _isOriginFieldFocused = false;
  final Set<Marker> _markers = {};

  LatLng? _origenLatLng;
  LatLng? _destinoLatLng;

  List<Map<String, dynamic>> _allActiveReports = [];
  List<Map<String, dynamic>> _filteredActiveReports = [];
  final Map<String, PolylineData> _routeCache = {};
  final String _normalRouteId = 'ruta_normal';
  final String _safeRouteId = 'ruta_segura';

  final Map<String, BitmapDescriptor> _iconBitmapCache = {};
  BitmapDescriptor? _origenIcon;

  TimeFilter _selectedTimeFilter = TimeFilter.all;
  bool _isRouteSearchVisible = false;
  bool _isLoadingRoute = false;

  static const double _buttonIconSize = 24.0;
  static const double _reportMarkerIconSize = 34.0;
  static const double _originMarkerIconSize = 72.0;


  final List<Map<String, dynamic>> _categories = [
    {'id': 'accident', 'name': 'Accidente', 'icon': Icons.car_crash, 'color': Colors.red},
    {'id': 'fire', 'name': 'Incendio', 'icon': Icons.local_fire_department, 'color': Colors.orange},
    {'id': 'roadblock', 'name': 'Vía bloqueada', 'icon': Icons.block, 'color': Colors.amber},
    {'id': 'protest', 'name': 'Manifestación', 'icon': Icons.people, 'color': Colors.yellow.shade700},
    {'id': 'theft', 'name': 'Robo', 'icon': Icons.money_off, 'color': Colors.purple},
    {'id': 'assault', 'name': 'Asalto', 'icon': Icons.personal_injury, 'color': Colors.deepPurple},
    {'id': 'violence', 'name': 'Violencia', 'icon': Icons.front_hand, 'color': Colors.red.shade800},
    {'id': 'vandalism', 'name': 'Vandalismo', 'icon': Icons.broken_image, 'color': Colors.indigo},
    {'id': 'others', 'name': 'Otros', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  String? _normalRouteInfo;
  String? _safeRouteInfo;

  static const double reportInfluenceRadiusMeters = 200.0;
  static const double detourCalculationRadiusDegrees = 0.0025;
  static const double detourOffsetDegrees = 0.0035;

  Map<String, dynamic>? _selectedReport;
  bool _isReportPanelVisible = false;
  AnimationController? _panelAnimationController;
  Animation<double>? _panelAnimation;
  final double _minPanelHeight = 80.0;
  final double _maxPanelHeight = 400.0;
  bool _isPanelExpanded = true;

  bool _isLeyendaVisible = false;

  FocusNode origenFocusNode = FocusNode();
  FocusNode destinoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _panelAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _panelAnimation = Tween<double>(begin: _minPanelHeight, end: _maxPanelHeight)
        .animate(CurvedAnimation(parent: _panelAnimationController!, curve: Curves.easeInOut));
    _prepareOriginIcon();
    initializeDateFormatting('es_ES', null).then((_) {
      _fetchAllActiveReports();
      _preguntarUsoUbicacionActual();
    }).catchError((_) {
      _fetchAllActiveReports();
      _preguntarUsoUbicacionActual();
    });
    origenFocusNode.addListener(_onOrigenFocusChange);
    destinoFocusNode.addListener(_onDestinoFocusChange);
  }

  @override
  void dispose() {
    origenController.dispose();
    destinoController.dispose();
    _mapController?.dispose();
    _panelAnimationController?.dispose();
    origenFocusNode.removeListener(_onOrigenFocusChange);
    origenFocusNode.dispose();
    destinoFocusNode.removeListener(_onDestinoFocusChange);
    destinoFocusNode.dispose();
    super.dispose();
  }

  void _onOrigenFocusChange() {
    if (mounted) {
      setState(() {
        _isOriginFieldFocused = origenFocusNode.hasFocus;
        if (!_isOriginFieldFocused && origenController.text.isNotEmpty && _origenLatLng == null) {
          _geocodeAndSetOrigin(origenController.text);
        } else if (_isOriginFieldFocused) {
          _placeSuggestions.clear();
        }
      });
    }
  }

  void _onDestinoFocusChange() {
     if (mounted) {
      setState(() {
        if (destinoFocusNode.hasFocus) {
            _isOriginFieldFocused = false; 
            _placeSuggestions.clear();
        }
        if (!destinoFocusNode.hasFocus && destinoController.text.isNotEmpty && _destinoLatLng == null) {
          _geocodeAndSetDestino(destinoController.text);
        }
      });
    }
  }
  
  Future<void> _geocodeAndSetOrigin(String address) async {
    final latLng = await _geocodeAddress(address);
    if (latLng != null && mounted) {
      _origenLatLng = latLng;
      await _updateOriginMarker(latLng, "Origen: ${origenController.text}");
      if (mounted) setState(_clearAllPolylinesAndCache);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    }
  }

  Future<void> _geocodeAndSetDestino(String address) async {
    final latLng = await _geocodeAddress(address);
    if (latLng != null && mounted) {
      _destinoLatLng = latLng;
      _updateDestMarker('destino', latLng, "Destino: ${destinoController.text}", BitmapDescriptor.hueRed);
       if (mounted) setState(_clearAllPolylinesAndCache);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    }
  }

  Map<String, dynamic> _getCategoryStyle(String? typeId) {
    final defaultCategory = _categories.firstWhere((cat) => cat['id'] == 'others',
        orElse: () => {'id': 'others', 'name': 'Otros', 'icon': Icons.help_outline, 'color': Colors.grey});
    final category = _categories.firstWhere((cat) => cat['id'] == typeId, orElse: () => defaultCategory);
    return {
      'iconData': category['icon'] ?? defaultCategory['icon'] ?? Icons.help_outline,
      'color': category['color'] ?? defaultCategory['color'] ?? Colors.grey,
      'name': category['name'] ?? defaultCategory['name'] ?? 'Desconocido'
    };
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromIconData(IconData iconData, Color color, {double size = 64.0, bool isOriginMarker = false}) async {
    final String cacheKey = '${iconData.codePoint}_${color.value}_${size}_$isOriginMarker';
    if (_iconBitmapCache.containsKey(cacheKey)) return _iconBitmapCache[cacheKey]!;
    
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double iconSize = size * (isOriginMarker ? 0.7 : 0.6);
    final double circleRadius = size / 2;

    TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr)
      ..text = TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: isOriginMarker ? size * 0.8 : iconSize,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            color: color,
          ),
        )
      ..layout();

    if (isOriginMarker) {
      textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));
    } else {
      final Paint backgroundPaint = Paint()..color = color.withAlpha((0.25 * 255).round());
      canvas.drawCircle(Offset(circleRadius, circleRadius), circleRadius, backgroundPaint);
      final Paint borderPaint = Paint()..color = color.withAlpha((0.8 * 255).round())..style = PaintingStyle.stroke..strokeWidth = 2.5;
      canvas.drawCircle(Offset(circleRadius, circleRadius), circleRadius - 1.25, borderPaint);
      textPainter.paint(canvas, Offset((size - iconSize) / 2, (size - iconSize) / 2));
    }

    final ui.Image img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return BitmapDescriptor.defaultMarker; 
    
    final BitmapDescriptor descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
    _iconBitmapCache[cacheKey] = descriptor;
    return descriptor;
  }

  Future<void> _prepareOriginIcon() async {
    _origenIcon = await _bitmapDescriptorFromIconData(Icons.person_pin_circle, Colors.blue, size: _originMarkerIconSize, isOriginMarker: true);
    if (mounted) setState(() {});
  }

  Future<void> _fetchAllActiveReports() async {
    if (!mounted) return;
    setState(() => _isLoadingRoute = true);
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('Reportes').where('estado', isEqualTo: 'Activo').get();
      if (mounted) {
        _allActiveReports = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>; data['docId'] = doc.id; return data;
        }).where((r) => r['ubicacion'] != null && r['ubicacion']['latitud'] is num && r['ubicacion']['longitud'] is num).toList();
        _applyTimeFilterToReports();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar reportes: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  void _applyTimeFilterToReports() {
    if (!mounted) return;
    final now = DateTime.now();
    Duration? filterDuration;

    switch (_selectedTimeFilter) {
      case TimeFilter.last24Hours: filterDuration = const Duration(hours: 24); break;
      case TimeFilter.last12Hours: filterDuration = const Duration(hours: 12); break;
      case TimeFilter.last1Hour: filterDuration = const Duration(hours: 1); break;
      case TimeFilter.all: break;
    }

    _filteredActiveReports = filterDuration == null
        ? List.from(_allActiveReports)
        : _allActiveReports.where((r) {
            dynamic fecha = r['fechaCreacion'];
            if (fecha is Timestamp) return fecha.toDate().isAfter(now.subtract(filterDuration!));
            if (fecha is String) { try { return DateTime.parse(fecha).isAfter(now.subtract(filterDuration!)); } catch(_) { return false; }}
            return false;
          }).toList();
    
    if (mounted) setState(() {});
    
    _updateReportMarkers();
    
    if (_origenLatLng != null && _destinoLatLng != null && (_polylines.isNotEmpty || _normalRouteInfo != null || _safeRouteInfo != null)) {
      _showAllRoutes();
    }
  }

  Future<void> _updateReportMarkers() async {
    if (!mounted) return;
    Set<Marker> newReportMarkers = {};
    for (var reporte in _filteredActiveReports) {
      final ubicacion = reporte['ubicacion'];
      final LatLng pos = LatLng(ubicacion['latitud'].toDouble(), ubicacion['longitud'].toDouble());
      final String tipoReporte = reporte['tipo'] ?? 'others';
      final categoryStyle = _getCategoryStyle(tipoReporte);
      
      IconData iconData = categoryStyle['iconData'] as IconData? ?? Icons.help_outline;
      Color iconColor = categoryStyle['color'] as Color? ?? Colors.grey;

      final BitmapDescriptor iconBitmap = await _bitmapDescriptorFromIconData(iconData, iconColor, size: _reportMarkerIconSize);
      newReportMarkers.add(Marker(
        markerId: MarkerId('reporte_${reporte['docId']}'),
        position: pos,
        icon: iconBitmap,
        onTap: () => _showReportDetailsPanel(reporte),
      ));
    }
    if (mounted) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value.startsWith('reporte_'));
        _markers.addAll(newReportMarkers);
      });
    }
  }

  void _showReportDetailsPanel(Map<String, dynamic> reporte) {
    if (!mounted) return;
    setState(() {
      _selectedReport = reporte;
      _isReportPanelVisible = true;
      _isPanelExpanded = true;
      _panelAnimationController?.forward();
    });
  }

  void _toggleReportPanelExpansion() {
    if (!mounted) return;
    setState(() {
      _isPanelExpanded = !_isPanelExpanded;
      if (_isPanelExpanded) {
        _panelAnimationController?.forward();
      } else {
        _panelAnimationController?.reverse();
      }
    });
  }

  void _hideReportPanel() {
    if (!mounted) return;
    setState(() {
      _isReportPanelVisible = false;
      _selectedReport = null;
      _panelAnimationController?.reset();
    });
  }

  void _toggleLeyenda() => mounted ? setState(() => _isLeyendaVisible = !_isLeyendaVisible) : null;
  void _closeLeyenda() => mounted ? setState(() => _isLeyendaVisible = false) : null;
  void _handleLogout() => mounted ? Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false) : null;
  
  Future<void> _navigateToPrincipalScreen() async {
    if (!mounted) return;
    await Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ScreenPrincipal()));
  }

  void _toggleRouteSearch() {
    if (!mounted) return;
    setState(() {
      _isRouteSearchVisible = !_isRouteSearchVisible;
      if (!_isRouteSearchVisible) {
        _placeSuggestions.clear();
        origenFocusNode.unfocus();
        destinoFocusNode.unfocus();
      }
    });
  }

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_getIconForLabel(label), size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    ),
  );

  IconData _getIconForLabel(String label) {
    if (label.contains("Descripción")) return Icons.description;
    if (label.contains("Nivel")) return Icons.warning;
    if (label.contains("Estado")) return Icons.info;
    if (label.contains("Fecha")) return Icons.calendar_today;
    return Icons.info_outline;
  }

  Future<void> _preguntarUsoUbicacionActual() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    bool? usarUbicacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usar ubicación actual'), content: const Text('¿Deseas usar tu ubicación actual como punto de origen?'),
        actions: [ TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')), ],
      ),
    );
    if (usarUbicacion == true) await _usarUbicacionActualComoOrigen();
  }

  Future<String> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first; 
        String address = [p.street, p.subLocality, p.locality, p.subAdministrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
        return address.isNotEmpty ? address : "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
      }
    } catch (_) {  }
    return "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
  }

  Future<void> _updateOriginMarker(LatLng position, String title) async {
    if (!mounted) return;
    _origenIcon ??= await _bitmapDescriptorFromIconData(Icons.person_pin_circle, Colors.blue, size: _originMarkerIconSize, isOriginMarker: true);
    final marker = Marker(markerId: const MarkerId('origen'), position: position, infoWindow: InfoWindow(title: title), icon: _origenIcon!, zIndex: 3);
    if(mounted) setState(() { _markers.removeWhere((m) => m.markerId.value == 'origen'); _markers.add(marker); });
  }

  void _updateDestMarker(String id, LatLng position, String title, double hue) {
    if (!mounted) return;
    final marker = Marker(markerId: MarkerId(id), position: position, infoWindow: InfoWindow(title: title), icon: BitmapDescriptor.defaultMarkerWithHue(hue));
     if(mounted) setState(() { _markers.removeWhere((m) => m.markerId.value == id); _markers.add(marker); });
  }

  Future<void> _usarUbicacionActualComoOrigen() async {
    if (!mounted) return;
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Habilita el servicio de ubicación.'))); return; }
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso denegado.'))); return; }
    }
    if (permiso == LocationPermission.deniedForever && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso denegado permanentemente.'))); return; }

    if (permiso == LocationPermission.whileInUse || permiso == LocationPermission.always) {
      try {
        if(mounted) setState(() => _isLoadingRoute = true);
        Position posicion = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10));
        final origenLatLng = LatLng(posicion.latitude, posicion.longitude);
        String direccion = await _getAddressFromLatLng(origenLatLng);
        if (mounted) {
          _origenLatLng = origenLatLng;
          origenController.text = direccion;
          await _updateOriginMarker(origenLatLng, "Origen: Actual");
          setState(_clearAllPolylinesAndCache);
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(origenLatLng, 15));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener ubicación: $e')));
          origenController.clear(); _origenLatLng = null;
          _markers.removeWhere((m) => m.markerId.value == 'origen');
          _clearAllPolylinesAndCache();
        }
      } finally {
        if(mounted) setState(() => _isLoadingRoute = false);
      }
    }
  }

  Future<void> _getPlaceSuggestions(String query, {bool forOrigin = false}) async {
    if (query.isEmpty) { if (mounted) setState(() => _placeSuggestions = []); return; }
    if (_isFetchingSuggestions) return;
    if (mounted) setState(() => _isFetchingSuggestions = true);
    g_places.Location? locationBias = _origenLatLng != null ? g_places.Location(lat: _origenLatLng!.latitude, lng: _origenLatLng!.longitude) : g_places.Location(lat: _kInitialPosition.target.latitude, lng: _kInitialPosition.target.longitude);
    final response = await _places.autocomplete(query, location: locationBias, radius: 50000, language: 'es', components: [g_places.Component("country", "pe")]);
    if (mounted) {
      if (response.isOkay) {
         setState(() => _placeSuggestions = response.predictions);
      } else { 
        setState(() => _placeSuggestions = []); 
      }
      setState(() => _isFetchingSuggestions = false);
    }
  }

  Future<void> _getPlaceDetailsAndSet(g_places.Prediction suggestion, {required bool isOrigin}) async {
    if (suggestion.placeId == null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo obtener detalles.'))); return; }
    final detailsResponse = await _places.getDetailsByPlaceId(suggestion.placeId!);
    if (mounted) {
      if (detailsResponse.isOkay && detailsResponse.result.geometry != null) {
        final lat = detailsResponse.result.geometry!.location.lat; final lng = detailsResponse.result.geometry!.location.lng;
        final placeLatLng = LatLng(lat, lng); String placeDescription = suggestion.description ?? "$lat, $lng";
        if (isOrigin) {
            origenController.text = placeDescription; _origenLatLng = placeLatLng;
            await _updateOriginMarker(placeLatLng, "Origen: ${suggestion.structuredFormatting?.mainText ?? ''}");
        } else {
            destinoController.text = placeDescription; _destinoLatLng = placeLatLng;
            _updateDestMarker('destino', placeLatLng, "Destino: ${suggestion.structuredFormatting?.mainText ?? ''}", BitmapDescriptor.hueRed);
        }
        setState(() { _placeSuggestions.clear(); _clearAllPolylinesAndCache(); });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(placeLatLng, 15));
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener detalles: ${detailsResponse.errorMessage}')));
      }
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (address.isEmpty) return null;
    try {
      final response = await _places.searchByText(address, location: g_places.Location(lat: _kInitialPosition.target.latitude, lng: _kInitialPosition.target.longitude), radius: 50000, language: 'es', region: 'pe');
      if (response.isOkay && response.results.isNotEmpty) {
        final geom = response.results.first.geometry;
        if (geom != null) return LatLng(geom.location.lat, geom.location.lng);
      }
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) return LatLng(locations.first.latitude, locations.first.longitude);
    } catch (_) {  }
    return null;
  }

  void _clearAllPolylinesAndCache() {
    if (mounted) {
        setState(() {
            _polylines.clear();
            _normalRouteInfo = null;
            _safeRouteInfo = null;
        });
    }
    _routeCache.clear();
  }

  Future<void> _handleMapTap(LatLng tappedPoint) async {
    if (!mounted) return;
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seleccionar Punto'), content: const Text('¿Usar como origen o destino?'),
        actions: <Widget>[ TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop(null)), TextButton(child: const Text('Origen', style: TextStyle(color: Colors.blue)), onPressed: () => Navigator.of(context).pop('origen')), TextButton(child: const Text('Destino', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop('destino')), ],
      ),
    );
    if (choice == null || !mounted) return; 
    String address = await _getAddressFromLatLng(tappedPoint);
    if (choice == 'origen') {
      origenController.text = address; _origenLatLng = tappedPoint;
      await _updateOriginMarker(tappedPoint, "Origen: Mapa");
    } else if (choice == 'destino') {
      destinoController.text = address; _destinoLatLng = tappedPoint;
      _updateDestMarker('destino', tappedPoint, "Destino: Mapa", BitmapDescriptor.hueRed);
    }
    if (mounted) setState(_clearAllPolylinesAndCache);
    _mapController?.animateCamera(CameraUpdate.newLatLng(tappedPoint));
  }

  Future<void> _getAndDisplayRoute({
    required LatLng origin,
    required LatLng destination,
    required RouteType routeType,
    List<LatLng> detourWaypoints = const [],
    bool fetchAlternativesForSafeRoute = false
  }) async {
    String routeTypeStr = routeType.toString().split('.').last;
    String detourHash = detourWaypoints.isNotEmpty ? "_detour_${detourWaypoints.map((p) => p.hashCode).join('_')}" : "";
    String polylineIdStr = routeType == RouteType.normal ? _normalRouteId : "$_safeRouteId$detourHash";
    Color routeColor = routeType == RouteType.normal ? Colors.lightBlueAccent : Colors.green.shade600;
    if(detourWaypoints.isNotEmpty && routeType == RouteType.safe) routeColor = Colors.green.shade800;
    
    double routeZIndex = routeType == RouteType.normal ? 1 : 2;
    String cacheKey = "${origin.latitude},${origin.longitude}_${destination.latitude},${destination.longitude}_$routeTypeStr$detourHash${fetchAlternativesForSafeRoute && detourWaypoints.isEmpty ? "_google_alt" : ""}";

    if (_routeCache.containsKey(cacheKey)) {
      final cachedData = _routeCache[cacheKey]!;
      if (mounted) {
        setState(() {
          _polylines.removeWhere((p) => p.polylineId.value == cachedData.polylineId);
          _polylines.add(Polyline(polylineId: PolylineId(cachedData.polylineId), points: cachedData.coordinates, color: cachedData.color, width: 6, zIndex: cachedData.zIndex.toInt()));
          if (routeType == RouteType.normal) {
            _normalRouteInfo = "${cachedData.distanceText ?? ''}, ${cachedData.durationText ?? ''}";
          } else {
            _safeRouteInfo = "${cachedData.distanceText ?? ''}, ${cachedData.durationText ?? ''} ${cachedData.isDetour ? '(Ruta Segura con Desvío)' : '(Ruta Segura - Alternativa Google)'}";
          }
        });
      }
      return;
    }

    String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&language=es&key=$googleMapsApiKey';
    if (detourWaypoints.isNotEmpty) {
      url += '&waypoints=${detourWaypoints.map((p) => "via:${p.latitude},${p.longitude}").join('|')}';
    } else if (routeType == RouteType.safe && fetchAlternativesForSafeRoute) url += '&alternatives=true';

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          int routeIdxToUse = (routeType == RouteType.safe && detourWaypoints.isEmpty && fetchAlternativesForSafeRoute && (data['routes'] as List).length > 1) ? 1 : 0;
          final apiRoute = data['routes'][routeIdxToUse];
           if (apiRoute['legs'] is List && (apiRoute['legs'] as List).isNotEmpty) {
              final leg = apiRoute['legs'][0];
              String distanceText = leg['distance']?['text'] ?? 'N/A';
              String durationText = leg['duration']?['text'] ?? 'N/A';
              List<LatLng> routeCoordinates = [];
              if (leg['steps'] is List) {
                for (var step in leg['steps']) {
                  if(step['polyline']?['points'] is String) {
                    routeCoordinates.addAll(_decodePolyline(step['polyline']['points']));
                  }
                }
              }
              if (routeCoordinates.isEmpty && mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se decodificó ruta $polylineIdStr.'))); return; }
              
              final polylineData = PolylineData(coordinates: routeCoordinates, color: routeColor, polylineId: polylineIdStr, zIndex: routeZIndex, distanceText: distanceText, durationText: durationText, isDetour: detourWaypoints.isNotEmpty);
              _routeCache[cacheKey] = polylineData;

              if (mounted) {
                setState(() {
                  if (routeType == RouteType.normal) {
                    _polylines.removeWhere((p) => p.polylineId.value == _normalRouteId);
                  } else {
                    _polylines.removeWhere((p) => p.polylineId.value.startsWith(_safeRouteId));
                  }
                  _polylines.add(Polyline(polylineId: PolylineId(polylineIdStr), points: routeCoordinates, color: routeColor, width: 6, zIndex: routeZIndex.toInt()));
                  if (routeType == RouteType.normal) {
                    _normalRouteInfo = "$distanceText, $durationText";
                  } else {
                    _safeRouteInfo = "$distanceText, $durationText ${detourWaypoints.isNotEmpty ? '(Ruta Segura con Desvío)' : '(Ruta Segura - Alternativa Google)'}";
                  }
                });
                bool shouldAnimate = (routeType == RouteType.normal && _polylines.where((p)=> p.polylineId.value.startsWith(_safeRouteId)).isEmpty) || (routeType == RouteType.safe);
                if (shouldAnimate || _polylines.length == 1) {
                     _mapController?.animateCamera(CameraUpdate.newLatLngBounds(_boundsFromLatLngList(routeCoordinates), 70));
                }
              }
           } else if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Formato de respuesta inesperado para ruta $polylineIdStr.'))); }
        } else if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se encontró ruta $polylineIdStr: ${data['status']}'))); }
      } else if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error API ruta $polylineIdStr: ${response.statusCode}'))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excepción ruta $polylineIdStr: $e'))); }
  }

  List<LatLng> _calculateDetourWaypointsForZone(LatLng origin, LatLng destination, LatLng zoneCenter, double zoneRadiusDegrees, List<LatLng> normalRoutePolyline) {
    if (normalRoutePolyline.length < 2) return [];
    List<LatLng> detourWaypoints = [];
    double minDistanceToZone = double.infinity;
    int entrySegmentIndex = -1;
    for (int i = 0; i < normalRoutePolyline.length; i++) {
        double dist = _calculateDistanceHaversine(normalRoutePolyline[i], zoneCenter);
        if (dist < minDistanceToZone) {
            minDistanceToZone = dist;
            entrySegmentIndex = i > 0 ? i -1 : 0;
        }
    }
    double zoneRadiusMeters = zoneRadiusDegrees * 111000;
    if (minDistanceToZone > zoneRadiusMeters * 1.5) return [];
    
    LatLng pointBeforeZone = entrySegmentIndex > 0 ? normalRoutePolyline[entrySegmentIndex] : origin;
    int exitSegmentCandidateIndex = entrySegmentIndex + 2 < normalRoutePolyline.length ? entrySegmentIndex + 2 : normalRoutePolyline.length -1;
    LatLng pointAfterZone = normalRoutePolyline[exitSegmentCandidateIndex];
    double routeSegmentDx = pointAfterZone.longitude - pointBeforeZone.longitude;
    double routeSegmentDy = pointAfterZone.latitude - pointBeforeZone.latitude;
    double perpDx = -routeSegmentDy;
    double perpDy = routeSegmentDx;
    double magnitude = sqrt(perpDx * perpDx + perpDy * perpDy);
    if (magnitude < 0.00001) {
        perpDx = -(destination.latitude - origin.latitude);
        perpDy = destination.longitude - origin.longitude;
        magnitude = sqrt(perpDx * perpDx + perpDy * perpDy);
        if (magnitude < 0.00001) return [];
    }
    perpDx /= magnitude;
    perpDy /= magnitude;
    double detourDistanceDegrees = detourOffsetDegrees + zoneRadiusDegrees;
    detourWaypoints.add(LatLng(zoneCenter.latitude + perpDy * detourDistanceDegrees, zoneCenter.longitude + perpDx * detourDistanceDegrees));
    return detourWaypoints;
  }

  double _calculateDistanceHaversine(LatLng p1, LatLng p2) {
    const R = 6371e3;
    final phi1 = p1.latitude * pi / 180; final phi2 = p2.latitude * pi / 180;
    final deltaPhi = (p2.latitude - p1.latitude) * pi / 180;
    final deltaLambda = (p2.longitude - p1.longitude) * pi / 180;
    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> _showAllRoutes() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    if (mounted) setState(() => _isLoadingRoute = true);

    if (_origenLatLng == null && origenController.text.isNotEmpty) {
      final geocodedOrigin = await _geocodeAddress(origenController.text);
      if (geocodedOrigin != null && mounted) { 
        _origenLatLng = geocodedOrigin; 
        await _updateOriginMarker(geocodedOrigin, "Origen: ${origenController.text}"); 
      } else { 
        if (mounted) { 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Origen no válido.'))); 
          setState(() => _isLoadingRoute = false); 
        } 
        return; 
      }
    }
    if (_destinoLatLng == null && destinoController.text.isNotEmpty) {
      final geocodedDestino = await _geocodeAddress(destinoController.text);
      if (geocodedDestino != null && mounted) { 
        _destinoLatLng = geocodedDestino; 
        _updateDestMarker('destino', geocodedDestino, "Destino: ${destinoController.text}", BitmapDescriptor.hueRed); 
      } else { 
        if (mounted) { 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destino no válido.'))); 
          setState(() => _isLoadingRoute = false); 
        } 
        return; 
      }
    }
    if (_origenLatLng == null || _destinoLatLng == null) { 
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona origen y destino.'))); 
        setState(() => _isLoadingRoute = false); 
      } 
      return; 
    }

    if(mounted) setState(_clearAllPolylinesAndCache);
    
    await _getAndDisplayRoute(origin: _origenLatLng!, destination: _destinoLatLng!, routeType: RouteType.normal);
    String normalRouteCacheKey = "${_origenLatLng!.latitude},${_origenLatLng!.longitude}_${_destinoLatLng!.latitude},${_destinoLatLng!.longitude}_${RouteType.normal.toString().split('.').last}";
    PolylineData? normalRouteData = _routeCache[normalRouteCacheKey];

    if (normalRouteData == null || normalRouteData.coordinates.isEmpty) {
        await _getAndDisplayRoute(origin: _origenLatLng!, destination: _destinoLatLng!, routeType: RouteType.safe, fetchAlternativesForSafeRoute: true);
        if (mounted) setState(() => _isLoadingRoute = false);
        return;
    }
    List<Map<String, dynamic>> reportsNearRouteForAvoidance = _filteredActiveReports.where((reporte) {
      final ubicacion = reporte['ubicacion'];
      LatLng puntoReporte = LatLng(ubicacion['latitud'].toDouble(), ubicacion['longitud'].toDouble());
      for (LatLng routePoint in normalRouteData.coordinates) {
          if (_calculateDistanceHaversine(routePoint, puntoReporte) < reportInfluenceRadiusMeters) return true;
      }
      return false;
    }).toList();

    if (reportsNearRouteForAvoidance.isNotEmpty) {
        double sumLat = 0, sumLng = 0;
        for(var r in reportsNearRouteForAvoidance) { sumLat += r['ubicacion']['latitud']; sumLng += r['ubicacion']['longitud']; }
        LatLng mainCongestionCenter = LatLng(sumLat / reportsNearRouteForAvoidance.length, sumLng / reportsNearRouteForAvoidance.length);
        List<LatLng> detourWps = _calculateDetourWaypointsForZone(_origenLatLng!, _destinoLatLng!, mainCongestionCenter, detourCalculationRadiusDegrees, normalRouteData.coordinates);
        if (detourWps.isNotEmpty) {
            await _getAndDisplayRoute(origin: _origenLatLng!, destination: _destinoLatLng!, routeType: RouteType.safe, detourWaypoints: detourWps);
            if (mounted) setState(() => _isLoadingRoute = false);
            return;
        }
    }
    await _getAndDisplayRoute(origin: _origenLatLng!, destination: _destinoLatLng!, routeType: RouteType.safe, fetchAlternativesForSafeRoute: true);
    if (mounted) setState(() => _isLoadingRoute = false);
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double x0 = list.first.latitude, x1 = list.first.latitude;
    double y0 = list.first.longitude, y1 = list.first.longitude;
    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }
    return LatLngBounds(northeast: LatLng(x1, y1), southwest: LatLng(x0, y0));
  }

  String _formatReportDate(Map<String, dynamic> reporte) {
    String fechaFormateada = "No disponible";
    dynamic fechaData = reporte['fechaCreacion'] ?? reporte['fechaCreacionLocal'];
    if (fechaData is Timestamp) {
      try { fechaFormateada = DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format(fechaData.toDate()); }
      catch (e) { fechaFormateada = fechaData.toDate().toLocal().toString().substring(0, 16); }
    } else if (fechaData is String) {
      try { DateTime dt = DateTime.parse(fechaData); fechaFormateada = DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format(dt); }
      catch (e) { fechaFormateada = fechaData; }
    }
    return fechaFormateada;
  }

  Widget _buildAddressTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required FocusNode focusNode,
    required bool isOriginField,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onFieldSubmitted,
    required VoidCallback onClear,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, size: 18),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear)
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      style: const TextStyle(fontSize: 14),
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
    );
  }

  Widget _buildSuggestionsListWidget() {
    return Material(
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _placeSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _placeSuggestions[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.location_pin, color: Colors.grey, size: 18),
              title: Text(suggestion.structuredFormatting?.mainText ?? suggestion.description ?? '', style: const TextStyle(fontSize: 14)),
              subtitle: Text(suggestion.structuredFormatting?.secondaryText ?? '', style: const TextStyle(fontSize: 12)),
              onTap: () {
                FocusScope.of(context).unfocus();
                _getPlaceDetailsAndSet(suggestion, isOrigin: _isOriginFieldFocused);
              },
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildRouteInfoDisplay(String? normalInfo, String? safeInfo) {
    if (normalInfo == null && safeInfo == null) {
      return const SizedBox.shrink();
    }

    List<Widget> routeWidgets = [];

    if (normalInfo != null) {
      routeWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.route, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Ruta Normal: $normalInfo",
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (safeInfo != null) {
      bool isDetour = safeInfo.contains('Desvío');
      
      routeWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(isDetour ? Icons.alt_route : Icons.shield_outlined, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  safeInfo, 
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: routeWidgets,
      ),
    );
  }

  Widget _buildRouteSearchPanelWidget(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 15.0,
      left: 10, 
      right: 10,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAddressTextField(
                          controller: origenController,
                          hintText: 'Origen',
                          prefixIcon: Icons.my_location,
                          focusNode: origenFocusNode,
                          isOriginField: true,
                          onChanged: (value) { if (origenFocusNode.hasFocus) { _getPlaceSuggestions(value, forOrigin: true); } },
                          onFieldSubmitted: (value) async {
                            origenFocusNode.unfocus();
                            if (value.isNotEmpty) await _geocodeAndSetOrigin(value);
                          },
                          onClear: () { if (mounted) setState(() { origenController.clear(); _origenLatLng = null; _markers.removeWhere((m) => m.markerId.value == 'origen'); _placeSuggestions.clear(); _clearAllPolylinesAndCache(); }); }
                        ),
                        if (_isOriginFieldFocused && _placeSuggestions.isNotEmpty) 
                            Padding(padding: const EdgeInsets.only(top: 4.0), child: _buildSuggestionsListWidget()),
                        
                        if (!(_isOriginFieldFocused && _placeSuggestions.isNotEmpty)) const SizedBox(height: 8),

                        _buildAddressTextField(
                          controller: destinoController,
                          hintText: 'Destino',
                          prefixIcon: Icons.location_on,
                          focusNode: destinoFocusNode,
                          isOriginField: false,
                          onChanged: (value) { if (destinoFocusNode.hasFocus) { _getPlaceSuggestions(value, forOrigin: false); } },
                          onFieldSubmitted: (value) async {
                            destinoFocusNode.unfocus();
                            if (value.isNotEmpty) await _geocodeAndSetDestino(value);
                          },
                          onClear: () { if (mounted) setState(() { destinoController.clear(); _destinoLatLng = null; _markers.removeWhere((m) => m.markerId.value == 'destino'); _placeSuggestions.clear(); _clearAllPolylinesAndCache(); }); }
                        ),
                         if (!_isOriginFieldFocused && _placeSuggestions.isNotEmpty && destinoFocusNode.hasFocus) 
                            Padding(padding: const EdgeInsets.only(top: 4.0), child: _buildSuggestionsListWidget()),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: _toggleRouteSearch),
                ],
              ),
              if (!(_isOriginFieldFocused && _placeSuggestions.isNotEmpty) && !(!_isOriginFieldFocused && _placeSuggestions.isNotEmpty && destinoFocusNode.hasFocus))
                const SizedBox(height: 8),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isLoadingRoute ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.alt_route, size: 18),
                  onPressed: _isLoadingRoute ? null : _showAllRoutes,
                  label: Text(_isLoadingRoute ? "Buscando..." : "Mostrar Rutas", style: const TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                ),
              ),
              _buildRouteInfoDisplay(_normalRouteInfo, _safeRouteInfo),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildReportDetailsPanelWidget() {
    if (!_isReportPanelVisible || _selectedReport == null) return const SizedBox.shrink();
    final report = _selectedReport!;
    final categoryStyle = _getCategoryStyle(report['tipo']);
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) { 
          if (details.primaryDelta! > 0 && _isPanelExpanded) {
            _toggleReportPanelExpansion();
          } else if (details.primaryDelta! < 0 && !_isPanelExpanded) _toggleReportPanelExpansion();
        },
        child: AnimatedBuilder(
          animation: _panelAnimation!,
          builder: (context, child) {
            return Container(
              height: _panelAnimation!.value,
              decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -2)) ]),
              child: SingleChildScrollView(
                physics: _isPanelExpanded ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (categoryStyle['color'] as Color).withAlpha((0.2 * 255).round()), shape: BoxShape.circle), child: Icon(categoryStyle['iconData'] as IconData, color: categoryStyle['color'] as Color, size: _buttonIconSize)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(report['titulo'] ?? 'Reporte sin título', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(categoryStyle['name'] as String, style: TextStyle(fontSize: 16, color: categoryStyle['color'] as Color, fontWeight: FontWeight.w500)),
                                      Text(_formatReportDate(report), style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: _hideReportPanel),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('Detalles del reporte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildDetailRow("Descripción", report['descripcion'] ?? 'Sin descripción'),
                      _buildDetailRow("Nivel de Riesgo", report['nivelRiesgo'] ?? 'No especificado'),
                      _buildDetailRow("Estado", report['estado'] ?? 'No especificado'),
                      if (report['imagenes'] is List && (report['imagenes'] as List).isNotEmpty)
                        _buildReportImagesSection(report['imagenes'] as List),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReportImagesSection(List<dynamic> imageUrls) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [ Icon(Icons.photo_library, color: Theme.of(context).primaryColor, size: _buttonIconSize), const SizedBox(width: 8), const Text('Imágenes del reporte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final imageUrl = imageUrls[index].toString();
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () => _showFullScreenImage(context, imageUrl),
                      child: Container(
                        width: 180,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300), boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2)) ]),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(imageUrl, fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
                              errorBuilder: (ctx, err, st) => Container(color: Colors.grey[200], child: Center(child: Icon(Icons.broken_image, size: 30, color: Colors.grey[400]))),
                            ),
                            Positioned(bottom: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.zoom_in, color: Colors.white, size: 16), SizedBox(width: 4), Text('Ampliar', style: TextStyle(color: Colors.white, fontSize: 12))]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              panEnabled: true, minScale: 0.5, maxScale: 4,
              child: Image.network(imageUrl, fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
                errorBuilder: (ctx, err, st) => Container(color: Colors.grey[200], child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey[400]))),
              ),
            ),
            Positioned(top: 20, right: 20, child: CircleAvatar(backgroundColor: Colors.black.withOpacity(0.5), child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()))),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCircularButton({required IconData icon, required String tooltip, required VoidCallback onPressed, Color backgroundColor = Colors.white, Color iconColor = Colors.black54, double opacity = 0.85}){
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor.withAlpha((opacity * 255).round()), 
        shape: BoxShape.circle, 
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 5, offset: const Offset(0, 2))]
      ),
      child: IconButton(icon: Icon(icon), color: iconColor, tooltip: tooltip, onPressed: onPressed),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BarraLateral(onLogout: _handleLogout),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialPosition,
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) => _mapController = controller,
            onTap: _handleMapTap,
          ),

          Positioned(
            top: 40, left: 20,
            child: SafeArea(
              child: Builder(
                builder: (context) => _buildCircularButton(
                  icon: Icons.menu, 
                  tooltip: 'Abrir menú', 
                  onPressed: () => Scaffold.of(context).openDrawer()
                ),
              ),
            ),
          ),

          Positioned(
            top: 40, right: 20,
            child: SafeArea(
              child: _buildCircularButton(
                icon: Icons.info_outline, 
                tooltip: 'Leyenda del mapa', 
                onPressed: _toggleLeyenda
              ),
            ),
          ),

          Positioned(
            top: 100, left: 20,
            child: SafeArea(
              child: Container( 
                decoration: BoxDecoration(color: Colors.white.withAlpha(217), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 5, offset: const Offset(0, 2))]),
                child: PopupMenuButton<TimeFilter>(
                  icon: const Icon(Icons.filter_list, color: Colors.black54), tooltip: "Filtrar reportes",
                  onSelected: (TimeFilter result) {
                    if (_selectedTimeFilter != result) {
                      if (mounted) setState(() => _selectedTimeFilter = result);
                      _applyTimeFilterToReports();
                    }
                  },
                  itemBuilder: (BuildContext context) => TimeFilter.values.map((filter) => PopupMenuItem<TimeFilter>(value: filter, child: Text(timeFilterToString(filter)))).toList(),
                ),
              ),
            ),
          ),
          Positioned(
            top: 100, right: 20,
            child: SafeArea(child: AlternarBoton(onPressed: _navigateToPrincipalScreen, tooltip: 'Ver mapa principal')),
          ),
          
          Positioned(
            bottom: 160,
            right: 20,
            child: SafeArea(
              child: _buildCircularButton(
                icon: Icons.directions, 
                tooltip: "Ruta Segura", 
                onPressed: _toggleRouteSearch,
                backgroundColor: Colors.blueAccent,
                iconColor: Colors.white,
                opacity: 0.9
              ),
            ),
          ),

          Positioned(
            bottom: 100,
            right: 20,
            child: SafeArea(
              child: _buildCircularButton(
                icon: Icons.my_location, 
                tooltip: 'Mi ubicación', 
                onPressed: _usarUbicacionActualComoOrigen
              ),
            ),
          ),

          const Positioned(
            bottom: 20, right: 20,
            child: SafeArea(child: EmergencyButton()),
          ),
          
          if (_isRouteSearchVisible) _buildRouteSearchPanelWidget(context),
          _buildReportDetailsPanelWidget(),
          
          if (_isLeyendaVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeLeyenda,
                child: Container(
                  color: Colors.black.withAlpha(153),
                  child: Center(
                    child: LeyendaMapa(
                      onClose: _closeLeyenda,
                      tipo: LeyendaTipo.rutaSegura,
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}