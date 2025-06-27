import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const String imgbbApiKey = '9e7f6853238e0d417d67f2c7c3d87282';

class ReporteFormularioScreen extends StatefulWidget {
  const ReporteFormularioScreen({super.key});

  @override
  State<ReporteFormularioScreen> createState() => _ReporteFormularioScreenState();
}

class _ReporteFormularioScreenState extends State<ReporteFormularioScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  String _riskLevel = 'Riesgo moderado';
  final List<XFile> _images = [];
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isLocationLoading = true;
  Position? _currentPosition;
  String _locationAddress = "Obteniendo ubicación...";

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

  final Map<String, Map<String, dynamic>> _riskLevelsData = {
    'Bajo':    {'color': Colors.green,  'icon': Icons.warning},
    'Medio':{'color': Colors.orange, 'icon': Icons.warning},
    'Alto':    {'color': Colors.red,    'icon': Icons.warning},
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() { _isLocationLoading = true; _locationAddress = "Obteniendo ubicación..."; });
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      if (mounted) setState(() { _isLocationLoading = false; _locationAddress = "No se pudo acceder a la ubicación"; });
      return;
    }
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showLocationServicesDialog();
        if (mounted) setState(() { _isLocationLoading = false; _locationAddress = "Servicios de ubicación desactivados";});
        return;
      }
      Position position = await Geolocator.getCurrentPosition( desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15), ).catchError((e) => throw e);
      if (mounted) setState(() { _currentPosition = position; _isLocationLoading = false; _locationAddress = "Ubicación obtenida correctamente"; });
    } catch (e) {
      if (mounted) setState(() { _isLocationLoading = false; _locationAddress = "Error al obtener ubicación"; });
    }
  }

  Future<bool> _handleLocationPermission() async {
    LocationPermission permission;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { if (mounted) _showLocationServicesDialog(); return false; }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Los permisos de ubicación fueron denegados')),);
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) { if (mounted) _showAppSettingsDialog(); return false; }
    return true;
  }

  void _showLocationServicesDialog() {
    if (!mounted) return;
    showDialog( context: context, barrierDismissible: false, builder: (BuildContext context) {
        return AlertDialog( title: const Text('Servicios de ubicación desactivados'), content: const Text('Para obtener la ubicación del incidente, necesitas activar los servicios de ubicación en tu dispositivo.'),
          actions: <Widget>[ TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()), TextButton( child: const Text('Abrir Configuración'), onPressed: () { Navigator.of(context).pop(); Geolocator.openLocationSettings(); },), ], ); }, );
  }

  void _showAppSettingsDialog() {
    if (!mounted) return;
    showDialog( context: context, barrierDismissible: false, builder: (BuildContext context) {
        return AlertDialog( title: const Text('Permisos de ubicación'), content: const Text('Los permisos de ubicación están permanentemente denegados. Por favor, habilítalos en la configuración de la aplicación.'),
          actions: <Widget>[ TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()), TextButton( child: const Text('Abrir Configuración'), onPressed: () { Navigator.of(context).pop(); Geolocator.openAppSettings(); },), ], ); }, );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_images.length >= 5) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Máximo 5 imágenes permitidas')), );
      return;
    }
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) { if (mounted) setState(() { _images.add(image); }); }
  }

  void _showImageSourceOptions() {
    if (!mounted) return;
    showModalBottomSheet( context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (BuildContext context) {
        return SafeArea( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisSize: MainAxisSize.min, children: [
                const Text('Seleccionar imagen desde', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
                Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _buildImageSourceOption(icon: Icons.camera_alt, title: 'Cámara', onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
                    _buildImageSourceOption(icon: Icons.photo_library, title: 'Galería', onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }), ], ),
                const SizedBox(height: 16), ], ), ), ); }, );
  }

  Widget _buildImageSourceOption({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector( onTap: onTap, child: Column( children: [
          Container( width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle), child: Icon(icon, size: 30, color: Colors.indigo[700]), ),
          const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), ], ), );
  }

  void _removeImage(int index) { if (mounted) setState(() { _images.removeAt(index); }); }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    final uri = Uri.parse('https://api.imgbb.com/1/upload');
    for (var imageXFile in _images) {
      try {
        var request = http.MultipartRequest('POST', uri);
        request.fields['key'] = imgbbApiKey;
        request.files.add( await http.MultipartFile.fromPath( 'image', imageXFile.path, filename: imageXFile.name, ), );
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 200) {
          var responseData = jsonDecode(response.body);
          if (responseData['success'] == true && responseData['data'] != null && responseData['data']['url'] != null) {
            imageUrls.add(responseData['data']['url']);
          } else { throw Exception('Error en la respuesta de la API de ImgBB: ${responseData['error']?['message'] ?? 'Respuesta inesperada'}'); }
        } else { throw Exception('Error al subir imagen a ImgBB. Código: ${response.statusCode}'); }
      } catch (e) { throw Exception('Fallo al subir la imagen ${imageXFile.name}: $e'); }
    }
    return imageUrls;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      if (_currentPosition == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('No se pudo obtener la ubicación. Por favor, inténtalo de nuevo.')), );
        return;
      }
      if (_titleController.text.trim().isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Por favor ingresa un título para el incidente')), );
        return;
      }
      if (mounted) setState(() { _isSubmitting = true; });
      try {
        List<String> imageUrls = await _uploadImages();
        final reporteData = {
          'id': const Uuid().v4(),
          'tipo': _selectedCategory,
          'titulo': _titleController.text.trim(),
          'descripcion': _descriptionController.text,
          'nivelRiesgo': _riskLevel,
          'ubicacion': {'latitud': _currentPosition!.latitude, 'longitud': _currentPosition!.longitude},
          'imagenes': imageUrls,
          'fechaCreacion': FieldValue.serverTimestamp(),
          'fechaCreacionLocal': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          'estado': 'Activo',
          'etapa': 'pendiente',
        };
        await FirebaseFirestore.instance.collection('Reportes').add(reporteData);
        if (!mounted) return;
        setState(() { 
          _isSubmitting = false; _selectedCategory = null; _titleController.clear(); _descriptionController.clear(); _images.clear(); _riskLevel = 'Riesgo moderado'; 
        });
        showDialog( context: context, barrierDismissible: false, builder: (BuildContext context) {
            return AlertDialog( shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 28), SizedBox(width: 10), Text('¡Reporte enviado!')]),
              content: const Text('Tu reporte ha sido enviado con éxito y está pendiente de verificación.', style: TextStyle(fontSize: 16)),
              actions: [ ElevatedButton( style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () { Navigator.of(context).pop(); if(mounted) setState(() {}); }, child: const Text('Aceptar'), ), ], ); }, );
      } catch (e) {
        if (mounted) { setState(() { _isSubmitting = false; }); ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error al enviar el reporte: $e')), ); }
      }
    } else if (_selectedCategory == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Por favor selecciona una categoría')), );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo[700],
        title: const Text('Reportar Incidente', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: _selectedCategory == null
          ? _buildCategorySelector()
          : _buildReportForm(),
    );
  }

  Widget _buildCategorySelector() {
    return SafeArea( child: Column( children: [
          const Padding( padding: EdgeInsets.all(16.0), child: Text( '¿Qué tipo de incidente deseas reportar?', style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, ), textAlign: TextAlign.center, ), ),
          Expanded( child: GridView.builder( padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 3, childAspectRatio: 0.8, crossAxisSpacing: 16, mainAxisSpacing: 16, ),
              itemCount: _categories.length, itemBuilder: (context, index) {
                final category = _categories[index];
                return InkWell( onTap: () { if (mounted) setState(() { _selectedCategory = category['id']; }); }, borderRadius: BorderRadius.circular(16),
                  child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container( width: 70, height: 70, decoration: BoxDecoration( color: category['color'].withOpacity(0.1), shape: BoxShape.circle, border: Border.all( color: category['color'], width: 2, ), ),
                        child: Icon( category['icon'], color: category['color'], size: 36, ), ),
                      const SizedBox(height: 8), Text( category['name'], style: const TextStyle( color: Colors.black87, fontWeight: FontWeight.bold, ), textAlign: TextAlign.center, ), ], ), ); }, ), ), ], ), );
  }

  Widget _buildReportForm() {
    final selectedCategoryData = _categories.firstWhere( (category) => category['id'] == _selectedCategory, );

    return SafeArea( child: Form( key: _formKey, child: ListView( padding: const EdgeInsets.all(16), children: [
            _buildSectionTitle('Tipo de Incidente'),
            Container( padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), decoration: BoxDecoration( color: selectedCategoryData['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all( color: selectedCategoryData['color'].withOpacity(0.3), width: 1, ), ),
              child: Row( children: [
                  Icon( selectedCategoryData['icon'], color: selectedCategoryData['color'], size: 28, ),
                  const SizedBox(width: 12), Text( selectedCategoryData['name'], style: TextStyle( color: selectedCategoryData['color'], fontWeight: FontWeight.bold, fontSize: 16, ), ),
                  const Spacer(),
                  TextButton.icon( onPressed: () { if (mounted) setState(() { _selectedCategory = null; }); }, icon: const Icon(Icons.edit, size: 16), label: const Text('Cambiar'), style: TextButton.styleFrom( foregroundColor: Colors.blue, ), ), ], ), ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Ubicación'),
            Container( padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), decoration: BoxDecoration( color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all( color: Colors.blue.withOpacity(0.3), width: 1, ), ),
              child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row( children: [
                      const Icon( Icons.location_on, color: Colors.blue, size: 24, ), const SizedBox(width: 12),
                      Expanded( child: _isLocationLoading ? Row( children: [ const SizedBox( width: 16, height: 16, child: CircularProgressIndicator( strokeWidth: 2, color: Colors.blue, ), ), const SizedBox(width: 8), Flexible( child: Text( _locationAddress, style: const TextStyle( color: Colors.black87, fontSize: 14, ), overflow: TextOverflow.ellipsis, ), ), ], )
                            : Text( _currentPosition != null ? 'Ubicación actual detectada' : 'No se pudo obtener la ubicación', style: TextStyle( color: _currentPosition != null ? Colors.black87 : Colors.red, fontSize: 14, ), overflow: TextOverflow.ellipsis, ), ),
                      if (!_isLocationLoading) IconButton( icon: const Icon(Icons.refresh, color: Colors.blue), onPressed: _getCurrentLocation, tooltip: 'Actualizar ubicación', ), ], ),
                  if (_currentPosition != null) ...[ const SizedBox(height: 8), Text( 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Long: ${_currentPosition!.longitude.toStringAsFixed(6)}', style: TextStyle( color: Colors.grey[600], fontSize: 12, ), ), ],
                  const SizedBox(height: 8), const Text( 'Tu ubicación actual será utilizada para geolocalizar el incidente', style: TextStyle( color: Colors.black54, fontSize: 12, fontStyle: FontStyle.italic, ), ), ], ), ),
            const SizedBox(height: 24),

            _buildSectionTitle('Título del Incidente'),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration( hintText: 'Ingresa un título breve para el incidente', filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!), ),
                enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!), ),
                focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue), ),
                contentPadding: const EdgeInsets.all(16), ),
              style: const TextStyle(color: Colors.black87),
              validator: (value) {
                if (value == null || value.isEmpty) { return 'Por favor ingresa un título para el incidente'; }
                return null;
              }, ),
            const SizedBox(height: 24),

            _buildSectionTitle('Descripción'),
            TextFormField( controller: _descriptionController, decoration: InputDecoration( hintText: 'Describe lo que está sucediendo con el mayor detalle posible...', filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!), ),
                enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!), ),
                focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue), ),
                contentPadding: const EdgeInsets.all(16), ), style: const TextStyle(color: Colors.black87), maxLines: 4,
              validator: (value) { if (value == null || value.isEmpty) { return 'Por favor ingresa una descripción'; } return null; }, ),
            const SizedBox(height: 24),

            _buildSectionTitle('Imágenes', trailing: '${_images.length}/5'),
            if (_images.isNotEmpty) Container( height: 120, margin: const EdgeInsets.only(bottom: 16), child: ListView.builder( scrollDirection: Axis.horizontal, itemCount: _images.length, itemBuilder: (context, index) {
                    return Stack( children: [ Container( width: 120, height: 120, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration( borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!), image: DecorationImage( image: FileImage(File(_images[index].path)), fit: BoxFit.cover, ), ), ),
                        Positioned( top: 8, right: 20, child: GestureDetector( onTap: () => _removeImage(index), child: Container( padding: const EdgeInsets.all(4), decoration: BoxDecoration( color: Colors.white, shape: BoxShape.circle, boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2), ), ], ),
                              child: const Icon( Icons.close, color: Colors.red, size: 16, ), ), ), ), ], ); }, ), ),
            InkWell( onTap: _showImageSourceOptions, borderRadius: BorderRadius.circular(12), child: Container( padding: const EdgeInsets.symmetric(vertical: 24), decoration: BoxDecoration( color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all( color: Colors.grey[300]!, width: 1, ), ),
                child: Column( children: [ Icon( Icons.add_photo_alternate, color: Colors.grey[600], size: 48, ), const SizedBox(height: 12),
                    Text( _images.isEmpty ? 'Toca para añadir imágenes' : 'Añadir más imágenes', style: TextStyle( color: Colors.grey[600], fontSize: 16, ), ),
                    const SizedBox(height: 4), Text( 'Puedes usar la cámara o seleccionar de la galería', style: TextStyle( color: Colors.grey[500], fontSize: 12, ), ), ], ), ), ),
            const SizedBox(height: 24),

            _buildSectionTitle('Nivel de Riesgo'),
            Row( children: _riskLevelsData.entries.map((entry) {
                final String riskName = entry.key; final Map<String, dynamic> riskData = entry.value; final bool isSelected = _riskLevel == riskName;
                return Expanded( child: GestureDetector( onTap: () { if (mounted) setState(() { _riskLevel = riskName; }); },
                    child: Container( margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration( color: isSelected ? riskData['color'].withOpacity(0.1) : Colors.grey[100], borderRadius: BorderRadius.circular(12),
                        border: Border.all( color: isSelected ? riskData['color'] : Colors.grey[300]!, width: 2, ),
                        boxShadow: isSelected ? [ BoxShadow( color: riskData['color'].withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2), ), ] : null, ),
                      child: Column( children: [ Icon( riskData['icon'], color: riskData['color'], size: isSelected ? 32 : 28, ), const SizedBox(height: 8),
                          Text( riskName, style: TextStyle( color: isSelected ? riskData['color'] : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14, ), textAlign: TextAlign.center, ), ], ), ), ), );
              }).toList(), ),
            const SizedBox(height: 32),

            ElevatedButton( onPressed: _isSubmitting ? null : _submitForm, style: ElevatedButton.styleFrom( backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), ), disabledBackgroundColor: Colors.blue.withOpacity(0.5), elevation: 4, ),
              child: _isSubmitting ? const Row( mainAxisAlignment: MainAxisAlignment.center, children: [ SizedBox( width: 20, height: 20, child: CircularProgressIndicator( color: Colors.white, strokeWidth: 2, ), ), SizedBox(width: 12), Text( 'Enviando...', style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold, ), ), ], )
                  : const Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.send, size: 22), SizedBox(width: 12), Text( 'Enviar reporte', style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold, ), ), ], ), ),
            const SizedBox(height: 24),
          ], ), ), );
  }

  Widget _buildSectionTitle(String title, {String? trailing}) {
    return Padding( padding: const EdgeInsets.only(bottom: 12), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text( title, style: const TextStyle( color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18, ), ),
          if (trailing != null) Text( trailing, style: TextStyle( color: Colors.grey[600], fontSize: 14, ), ), ], ), );
  }
}