import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:io' show Platform;
// No necesitamos importar './image_viewer_screen.dart' porque estará aquí

class ReportDetailsScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailsScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  final PageController _imagePageController = PageController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color colorPrimario = Color(0xFF1E3A8A);
  static const Color colorAcento = Color(0xFF3B82F6);
  static const Color colorTextoPrincipal = Color(0xFF1F2937);
  static const Color colorTextoSecundario = Color(0xFF4B5563);
  static const Color colorFondoTarjeta = Colors.white;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _loadReport();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() { _isLoading = true; });
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('Reportes')
          .doc(widget.reportId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _reportData = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
        _fadeController.forward();
      } else if (mounted) {
        setState(() { _isLoading = false; });
        _showErrorSnackBar('No se pudo encontrar el reporte');
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        _showErrorSnackBar('Error al cargar reporte: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getRiskColor(String? riesgo) {
    switch (riesgo?.toLowerCase()) {
      case 'alto': return Colors.red.shade600;
      case 'medio': return Colors.orange.shade600;
      case 'bajo': return Colors.green.shade600;
      default: return Colors.grey.shade500;
    }
  }

  IconData _getTypeIcon(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'robo': return Icons.security_outlined;
      case 'incendio': return Icons.local_fire_department_outlined;
      case 'accident':
      case 'accidente': return Icons.car_crash_outlined;
      case 'emergencia médica': return Icons.medical_services_outlined;
      case 'violencia': return Icons.warning_amber_rounded;
      default: return Icons.report_problem_outlined;
    }
  }

  String _getTranslatedReportType(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'robo': return 'Robo';
      case 'incendio': return 'Incendio';
      case 'accident':
      case 'accidente': return 'Accidente';
      case 'emergencia médica': return 'Emergencia Médica';
      case 'violencia': return 'Violencia';
      default: return tipo ?? 'Incidente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Detalles del Reporte'),
        backgroundColor: colorPrimario,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2.0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: colorPrimario))
          : _reportData == null
              ? const Center(
                  child: Text(
                    'No se pudo cargar la informacion del reporte.',
                    style: TextStyle(fontSize: 16, color: colorTextoSecundario),
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      if ((_reportData!['imagenes'] as List?)?.isNotEmpty ?? false)
                        _buildImageCarousel(_reportData!['imagenes'] as List),
                      if ((_reportData!['imagenes'] as List?)?.isNotEmpty ?? false)
                        const SizedBox(height: 16),
                      _buildInfoCard(
                        title: 'Informacion General',
                        icon: Icons.info_outline_rounded,
                        children: [
                          _buildInfoRow(Icons.label_outline, 'Tipo de Incidente', _getTranslatedReportType(_reportData!['tipo'])),
                          _buildInfoRow(Icons.access_time_outlined, 'Fecha y Hora', _formatTimestamp(_reportData!['fechaCreacion'])),
                          _buildInfoRow(Icons.location_on_outlined, 'Ubicacion', '${(_reportData!['ubicacion'] as Map<String, dynamic>?)?['latitud']?.toStringAsFixed(6) ?? 'N/D'}, ${(_reportData!['ubicacion'] as Map<String, dynamic>?)?['longitud']?.toStringAsFixed(6) ?? 'N/D'}'),
                          if (_reportData!['direccion'] != null && (_reportData!['direccion'] as String).isNotEmpty)
                            _buildInfoRow(Icons.place_outlined, 'Direccion', _reportData!['direccion']),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_reportData!['descripcion'] != null && (_reportData!['descripcion'] as String).isNotEmpty)
                        _buildInfoCard(
                          title: 'Descripcion del Incidente',
                          icon: Icons.description_outlined,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _reportData!['descripcion'],
                                style: const TextStyle(fontSize: 15, color: colorTextoSecundario, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      if (_reportData!['descripcion'] != null && (_reportData!['descripcion'] as String).isNotEmpty)
                        const SizedBox(height: 16),
                       _buildInfoCard(
                        title: 'Estado del Reporte',
                        icon: Icons.flag_outlined,
                        children: [
                           _buildInfoRow(
                            Icons.check_circle_outline,
                            'Estado Actual',
                            (_reportData!['estado'] as String?) == 'Activo' ? 'Activo' : 'Inactivo',
                            valueColor: (_reportData!['estado'] as String?) == 'Activo' ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    String riesgo = _reportData!['nivelRiesgo'] ?? 'Desconocido';
    String tipo = _reportData!['tipo'] ?? 'Incidente';
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorFondoTarjeta,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getRiskColor(riesgo).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_getTypeIcon(tipo), size: 30, color: _getRiskColor(riesgo),),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getTranslatedReportType(tipo), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorTextoPrincipal,),),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _getRiskColor(riesgo), borderRadius: BorderRadius.circular(20),),
                    child: Text('Riesgo $riesgo', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,),),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel(List<dynamic> imageUrls) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    List<String> validImageUrls = imageUrls.whereType<String>().toList();
    if (validImageUrls.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorFondoTarjeta,
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _imagePageController,
              itemCount: validImageUrls.length,
              itemBuilder: (context, index) {
                final imageUrl = validImageUrls[index];
                final heroTag = 'report_image_${widget.reportId}_$index';
                return Padding(
                  padding: const EdgeInsets.all(0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        ImageViewerScreen(imageUrl: imageUrl, heroTag: heroTag),
                      ));
                    },
                    child: Hero(
                      tag: heroTag,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: colorAcento)),
                        errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 50)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (validImageUrls.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: SmoothPageIndicator(
                controller: _imagePageController,
                count: validImageUrls.length,
                effect: WormEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  activeDotColor: colorPrimario,
                  dotColor: Colors.grey.shade300,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorFondoTarjeta,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorPrimario, size: 22),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colorTextoPrincipal,),),
              ],
            ),
            const Divider(height: 20, thickness: 0.8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, {Color? valueColor}) {
    if (value == null || value.isEmpty || value == 'N/D') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorTextoSecundario.withOpacity(0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600,),),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: valueColor ?? colorTextoPrincipal,),),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Fecha no disponible';
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Formato de fecha invalido';
      }
      return DateFormat('dd/MM/yyyy HH:mm', Platform.isAndroid || Platform.isIOS ? Platform.localeName : 'es').format(dateTime);
    } catch (e) {
      return 'Error en formato de fecha';
    }
  }
}

// -----------------------------------------------------------------------------
// Pantalla para Visualizar Imagen en Pantalla Completa
// -----------------------------------------------------------------------------
class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton( // Botón para cerrar
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer( // Permite hacer zoom y pan
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain, // Muestra la imagen completa
              placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 50)),
            ),
          ),
        ),
      ),
    );
  }
}