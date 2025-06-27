import 'package:cloud_firestore/cloud_firestore.dart';

class Noticia {
  final String id; // <-- Añadimos un ID para cada noticia
  final String titulo;
  final String fecha;
  final String hora;
  final String enlace;
  final String lugar;
  final String imagen_url;
  final String resumen;
  final String contenido;
  final String tipo;
  final String nivel;

  Noticia({
    required this.id,
    required this.titulo,
    required this.fecha,
    required this.hora,
    required this.enlace,
    required this.lugar,
    required this.imagen_url,
    required this.resumen,
    required this.contenido,
    required this.tipo,
    required this.nivel,
  });

  // Factory constructor para crear una instancia de Noticia desde un DocumentSnapshot de Firestore
  factory Noticia.fromFirestore(DocumentSnapshot doc) {
    // Obtener el mapa de datos del documento
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Devolvemos una nueva instancia de Noticia, asignando los valores
    // Usamos '??' para proveer un valor por defecto en caso de que un campo sea nulo
    return Noticia(
      id: doc.id, // El ID del documento de Firestore
      titulo: data['titulo'] ?? 'Sin título',
      fecha: data['fecha'] ?? 'Fecha no disponible',
      hora: data['hora'] ?? 'Hora no disponible',
      enlace: data['enlace'] ?? '',
      lugar: data['lugar'] ?? 'Ubicación no especificada',
      imagen_url: data['imagen_url'] ?? '',
      resumen: data['resumen'] ?? 'Sin resumen.',
      contenido: data['contenido'] ?? 'Contenido no disponible.',
      tipo: data['tipo'] ?? 'General',
      nivel: data['nivel'] ?? 'Bajo',
    );
  }
}