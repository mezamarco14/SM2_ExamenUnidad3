import 'package:flutter/material.dart';
import '../models/noticia_model.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- IMPORTAR PAQUETE

class NoticiaDetalleScreen extends StatelessWidget {
  final Noticia noticia;

  const NoticiaDetalleScreen({super.key, required this.noticia});

  // Función para abrir el enlace en un navegador
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'No se pudo lanzar $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(noticia.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.indigo[700],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de la noticia
            Image.network(
              noticia.imagen_url,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 250,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECCIÓN DE METADATOS ---
                  Wrap( // Wrap es genial para que los elementos se ajusten
                    spacing: 8.0, // Espacio horizontal entre chips
                    runSpacing: 4.0, // Espacio vertical si se van a una nueva línea
                    children: [
                      Chip(
                        avatar: Icon(Icons.category_outlined, color: Colors.indigo[800]),
                        label: Text(noticia.tipo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.indigo[100],
                      ),
                      Chip(
                        avatar: Icon(Icons.priority_high, color: Colors.orange[800]),
                        label: Text('Nivel: ${noticia.nivel}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.orange[100],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Título grande
                  Text(
                    noticia.titulo,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- INFORMACIÓN DETALLADA ---
                  _buildDetailRow(Icons.access_time_outlined, '${noticia.fecha} - ${noticia.hora}'),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.location_on_outlined, noticia.lugar),
                  
                  const Divider(height: 32, thickness: 1),

                  // Resumen
                  const Text(
                    'Resumen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    noticia.resumen,
                    style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black54),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Contenido completo
                  const Text(
                    'Contenido Completo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    noticia.contenido,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const Divider(height: 32, thickness: 1),

                  // --- ENLACE A LA FUENTE ORIGINAL ---
                  ListTile(
                    leading: const Icon(Icons.link, color: Colors.blue),
                    title: const Text(
                      'Ver fuente original',
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                    onTap: () {
                      _launchURL(noticia.enlace);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para no repetir código
  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, color: Colors.grey[900]),
          ),
        ),
      ],
    );
  }
}