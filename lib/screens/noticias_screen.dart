import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- 1. Importar Firestore
import '../models/noticia_model.dart';
import 'noticia_detalle_screen.dart';

// 2. Convertir a StatefulWidget para manejar el estado de carga y los datos
class NoticiasScreen extends StatefulWidget {
  const NoticiasScreen({super.key});

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  // 3. Variables para manejar el estado
  bool _isLoading = true;
  List<Noticia> _noticias = [];

  @override
  void initState() {
    super.initState();
    _cargarNoticias(); // 4. Cargar las noticias cuando la pantalla se inicie
  }

  // 5. Método para obtener los datos de Firestore (similar a tu _fetchAllReportPoints)
  Future<void> _cargarNoticias() async {
    try {
      // Ordenamos por 'timestamp_creacion' para ver las más nuevas primero
      QuerySnapshot noticiasSnapshot = await FirebaseFirestore.instance
          .collection('Noticias')
          .orderBy('timestamp_creacion', descending: true)
          .limit(20) // limitar a 20 noticias maximo
          .get();

      // Convertimos cada documento en un objeto Noticia usando nuestro factory
      final noticiasData = noticiasSnapshot.docs
          .map((doc) => Noticia.fromFirestore(doc))
          .toList();
      
      if (mounted) { // Importante verificar si el widget sigue en pantalla
        setState(() {
          _noticias = noticiasData;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar noticias: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noticias de la Comunidad'),
        backgroundColor: Colors.indigo[700],
      ),
      // 6. Mostramos un loader mientras carga, o la lista si ya cargó
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _noticias.length,
              itemBuilder: (context, index) {
                final noticia = _noticias[index]; // <-- Usamos la lista de Firebase
                // EL WIDGET Card ES EXACTAMENTE EL MISMO DE ANTES. ¡NO HAY QUE CAMBIARLO!
                return Card(
                  elevation: 4.0,
                  margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 5.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoticiaDetalleScreen(noticia: noticia),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 180,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: Image.network(
                            noticia.imagen_url,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined, size: 50, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text("No se pudo cargar la imagen", style: TextStyle(color: Colors.grey)),
                                ],
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(noticia.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Text(noticia.resumen, style: TextStyle(fontSize: 14, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text('${noticia.fecha} - ${noticia.hora}', style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(noticia.lugar, style: TextStyle(fontSize: 12, color: Colors.grey[800]), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(12))),
                          child: Chip(label: Text(noticia.tipo, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}