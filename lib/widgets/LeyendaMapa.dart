import 'package:flutter/material.dart';

enum LeyendaTipo { principal, rutaSegura }

class LeyendaMapa extends StatefulWidget {
  final VoidCallback onClose;
  final LeyendaTipo tipo;

  const LeyendaMapa({
    super.key,
    required this.onClose,
    required this.tipo,
  });

  @override
  State<LeyendaMapa> createState() => _LeyendaMapaState();
}

class _LeyendaMapaState extends State<LeyendaMapa>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  List<Widget> _leyendaItems = [];
  String _tituloLeyenda = 'Leyenda del Mapa';

  @override
  void initState() {
    super.initState();
    _buildLeyendaContent();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _cerrarLeyendaAnimada() {
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  void _buildLeyendaContent() {
    switch (widget.tipo) {
      case LeyendaTipo.principal:
        _tituloLeyenda = 'Leyenda Principal';
        _leyendaItems = [
          _buildLeyendaItemParaPrincipal(
            color: Colors.red.withOpacity(0.6),
            texto: 'Zona Peligrosa',
            descripcion:
                'Alto riesgo de incidentes. Se recomienda evitar estas áreas, especialmente durante la noche.',
          ),
          const SizedBox(height: 16),
          _buildLeyendaItemParaPrincipal(
            color: Colors.orange.withOpacity(0.6),
            texto: 'Zona de Riesgo Medio',
            descripcion:
                'Precaución recomendada. Manténgase alerta y evite mostrar objetos de valor.',
          ),
          const SizedBox(height: 16),
          _buildLeyendaItemParaPrincipal(
            color: Colors.green.withOpacity(0.6),
            texto: 'Zona Segura',
            descripcion:
                'Bajo riesgo de incidentes. Áreas generalmente seguras con buena vigilancia.',
          ),
          const SizedBox(height: 20),
          const Divider(height: 24, thickness: 1, color: Colors.black12),
          const Text(
            'Información Adicional',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoItemParaPrincipal(
            icon: Icons.access_time,
            texto: 'Datos actualizados cada 24 horas',
          ),
          const SizedBox(height: 8),
          _buildInfoItemParaPrincipal(
            icon: Icons.people,
            texto: 'Basado en reportes de usuarios y datos oficiales',
          ),
          const SizedBox(height: 8),
          _buildInfoItemParaPrincipal(
            icon: Icons.info_outline,
            texto: 'Toque en el mapa para ver detalles específicos',
          ),
        ];
        break;
      case LeyendaTipo.rutaSegura:
        _tituloLeyenda = 'Leyenda de Ruta Segura';
        final List<Map<String, dynamic>> categories = [
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
        _leyendaItems = [
          ...categories.map((category) => _buildLeyendaItemParaRutaSegura(
                icon: category['icon'] as IconData,
                color: category['color'] as Color,
                title: category['name'] as String,
                description: 'Reportes de tipo ${(category['name'] as String).toLowerCase()}',
              )),
          const SizedBox(height: 16),
          const Text(
            'Rutas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildLeyendaItemParaRutaSegura(
            icon: Icons.timeline,
            color: Colors.lightBlueAccent,
            title: 'Ruta Normal',
            description: 'Ruta directa entre origen y destino',
          ),
          _buildLeyendaItemParaRutaSegura(
            icon: Icons.timeline,
            color: Colors.green.shade600,
            title: 'Ruta Segura',
            description: 'Ruta alternativa que evita zonas de riesgo',
          ),
        ];
        break;
    }
  }

  Widget _buildLeyendaItemParaPrincipal({
    required Color color,
    required String texto,
    required String descripcion,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.8), width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              const SizedBox(height: 4),
              Text(descripcion, style: const TextStyle(color: Colors.black54, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItemParaPrincipal({ required IconData icon, required String texto }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 14, color: Colors.black54))),
      ],
    );
  }

  Widget _buildLeyendaItemParaRutaSegura({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(description, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: Dialog(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _tituloLeyenda,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 24, color: Colors.black54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Cerrar leyenda',
                          onPressed: _cerrarLeyendaAnimada,
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1, color: Colors.black12),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _leyendaItems,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cerrarLeyendaAnimada,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Entendido', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}