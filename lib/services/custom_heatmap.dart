import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ReportPoint {
  final LatLng position;
  ReportPoint(this.position);
}

class CustomHeatmapTileProvider implements TileProvider {
  final List<ReportPoint> allReportPoints;
  final int tileSize;
  final int radiusPixels;
  final List<Color> gradientColors;
  final List<double> gradientStops;
  
  // Cache para los tiles generados
  final Map<String, Uint8List> _tileCache = {};
  
  // Constante para el borde extra para evitar cortes entre tiles
  static const int _tileEdgeBuffer = 20;

  CustomHeatmapTileProvider({
    required this.allReportPoints,
    this.tileSize = 256,
    this.radiusPixels = 80,
    this.gradientColors = const [
      Color.fromARGB(0, 0, 255, 0),      // Transparente
      Color.fromARGB(150, 0, 255, 0),    // Verde (baja densidad)
      Color.fromARGB(180, 255, 255, 0),  // Amarillo (densidad media)
      Color.fromARGB(200, 255, 165, 0),  // Naranja
      Color.fromARGB(220, 255, 0, 0),    // Rojo (alta densidad)
    ],
    this.gradientStops = const [0.0, 0.3, 0.6, 0.8, 1.0],
  }) : assert(gradientColors.length == gradientStops.length);
  
  // Factor de reducción para cálculos - menor valor = mejor rendimiento pero menor precisión
  final int _downscaleFactor = 2;

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) {
      return TileProvider.noTile;
    }
    
    // Clave para el cache
    final String cacheKey = '$x-$y-$zoom';
    
    // Verificar si el tile ya está en cache
    if (_tileCache.containsKey(cacheKey)) {
      return Tile(tileSize, tileSize, _tileCache[cacheKey]!);
    }

    // Obtener los límites del tile con un buffer para evitar cortes
    final LatLngBounds tileBounds = _getTileBounds(x, y, zoom);
    final LatLngBounds expandedBounds = _getExpandedBounds(tileBounds);
    
    // Obtener puntos en el tile y en el área de buffer
    final List<ReportPoint> pointsInTile = allReportPoints.where((point) {
      return expandedBounds.contains(point.position);
    }).toList();

    if (pointsInTile.isEmpty) {
      final Uint8List emptyTileBytes = await _createTransparentTileBytes(tileSize, tileSize);
      _tileCache[cacheKey] = emptyTileBytes;
      return Tile(tileSize, tileSize, emptyTileBytes);
    }

    // Tamaño de la matriz de cálculo reducida
    final int calculationSize = tileSize ~/ _downscaleFactor;
    
    // Matriz para almacenar intensidades en resolución reducida
    final List<List<double>> intensityGrid = List.generate(
      calculationSize + _tileEdgeBuffer * 2 ~/ _downscaleFactor,
      (_) => List.filled(calculationSize + _tileEdgeBuffer * 2 ~/ _downscaleFactor, 0.0)
    );
    
    // Calcular la intensidad para cada punto
    for (final reportPoint in pointsInTile) {
      final Offset pixelOffset = _latLngToPixelOffset(
        reportPoint.position, 
        tileBounds, 
        tileSize.toDouble(), 
        zoom
      );
      
      // Convertir a coordenadas en la matriz de intensidad (reducida)
      final int baseX = (pixelOffset.dx / _downscaleFactor).round() + _tileEdgeBuffer ~/ _downscaleFactor;
      final int baseY = (pixelOffset.dy / _downscaleFactor).round() + _tileEdgeBuffer ~/ _downscaleFactor;
      
      // Radio reducido para la matriz de menor resolución
      final int reducedRadius = (radiusPixels / _downscaleFactor).ceil();
      
      // Optimización: precalcular el radio al cuadrado para evitar raíces cuadradas
      final int radiusSq = reducedRadius * reducedRadius;
      
      // Calcular intensidad para cada celda dentro del radio
      for (int dx = -reducedRadius; dx <= reducedRadius; dx++) {
        // Optimización: calcular dx² una sola vez por fila
        final int dxSq = dx * dx;
        
        for (int dy = -reducedRadius; dy <= reducedRadius; dy++) {
          // Optimización: verificar primero si estamos dentro del radio usando distancia al cuadrado
          final int distSq = dxSq + dy * dy;
          if (distSq > radiusSq) continue;
          
          final int gridX = baseX + dx;
          final int gridY = baseY + dy;
          
          // Verificar límites
          if (gridX >= 0 && gridX < intensityGrid.length && 
              gridY >= 0 && gridY < intensityGrid[0].length) {
            
            // Calcular intensidad usando distancia euclídea
            final double distance = math.sqrt(distSq.toDouble());
            
            // Función gaussiana para suavizar el efecto
            final double intensity = math.exp(-(distance * distance) / (2 * reducedRadius * reducedRadius / 4));
            intensityGrid[gridX][gridY] += intensity;
          }
        }
      }
    }
    
    // Encontrar la intensidad máxima para normalizar
    double maxIntensity = 0.0;
    for (final row in intensityGrid) {
      for (final intensity in row) {
        if (intensity > maxIntensity) {
          maxIntensity = intensity;
        }
      }
    }
    
    // Ajustar el umbral para que se necesiten más puntos para llegar a colores cálidos
    final double intensityThreshold = pointsInTile.length > 5 ? maxIntensity : maxIntensity * 1.5;
    
    // Crear la imagen del mapa de calor
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();
    
    // Escalar la matriz de intensidad de vuelta al tamaño del tile
    for (int x = 0; x < tileSize; x++) {
      for (int y = 0; y < tileSize; y++) {
        // Mapear coordenadas del tile a la matriz de intensidad
        final int gridX = (x / _downscaleFactor).round() + _tileEdgeBuffer ~/ _downscaleFactor;
        final int gridY = (y / _downscaleFactor).round() + _tileEdgeBuffer ~/ _downscaleFactor;
        
        // Verificar límites
        if (gridX >= 0 && gridX < intensityGrid.length && 
            gridY >= 0 && gridY < intensityGrid[0].length) {
          
          final double intensity = intensityGrid[gridX][gridY];
          
          if (intensity > 0) {
            // Normalizar la intensidad
            double normalizedIntensity = intensity / intensityThreshold;
            normalizedIntensity = math.min(normalizedIntensity, 1.0);
            
            // Obtener el color basado en la intensidad
            final Color color = _getColorForIntensity(normalizedIntensity);
            
            // Solo dibujar si el color no es completamente transparente
            if (color.alpha > 0) {
              paint.color = color;
              canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
            }
          }
        }
      }
    }

    // Aplicar suavizado para mejorar la apariencia
    final Paint blurPaint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5);
    canvas.saveLayer(Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()), blurPaint);
    canvas.restore();

    // Convertir a imagen
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(tileSize, tileSize);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    // Liberar recursos
    image.dispose();
    
    if (byteData != null) {
      final Uint8List tileBytes = byteData.buffer.asUint8List();
      // Guardar en cache
      _tileCache[cacheKey] = tileBytes;
      return Tile(tileSize, tileSize, tileBytes);
    } else {
      return TileProvider.noTile;
    }
  }

  // Ampliar los límites del tile para incluir un buffer
  LatLngBounds _getExpandedBounds(LatLngBounds bounds) {
    // Calcular la expansión en grados (aproximación)
    final double latExpansion = (bounds.northeast.latitude - bounds.southwest.latitude) * _tileEdgeBuffer / tileSize;
    final double lngExpansion = (bounds.northeast.longitude - bounds.southwest.longitude) * _tileEdgeBuffer / tileSize;
    
    return LatLngBounds(
      southwest: LatLng(
        bounds.southwest.latitude - latExpansion,
        bounds.southwest.longitude - lngExpansion
      ),
      northeast: LatLng(
        bounds.northeast.latitude + latExpansion,
        bounds.northeast.longitude + lngExpansion
      )
    );
  }

  // Obtener el color para una intensidad dada
  Color _getColorForIntensity(double intensity) {
    for (int i = 0; i < gradientStops.length - 1; i++) {
      if (intensity >= gradientStops[i] && intensity <= gradientStops[i + 1]) {
        final double t = (intensity - gradientStops[i]) / (gradientStops[i + 1] - gradientStops[i]);
        return Color.lerp(gradientColors[i], gradientColors[i + 1], t)!;
      }
    }
    return gradientColors.last;
  }

  // Métodos auxiliares sin cambios
  Future<Uint8List> _createTransparentTileBytes(int width, int height) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width, height);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List() ?? Uint8List(0);
  }

  LatLngBounds _getTileBounds(int x, int y, int zoom) {
    final int numTiles = 1 << zoom;
    final double longitudeStart = (x / numTiles) * 360.0 - 180.0;
    final double longitudeEnd = ((x + 1) / numTiles) * 360.0 - 180.0;
    final double n1 = math.pi - (2.0 * math.pi * y) / numTiles;
    final double n2 = math.pi - (2.0 * math.pi * (y + 1)) / numTiles;
    final double latitudeStart = (180.0 / math.pi) * math.atan(0.5 * (math.exp(n1) - math.exp(-n1)));
    final double latitudeEnd = (180.0 / math.pi) * math.atan(0.5 * (math.exp(n2) - math.exp(-n2)));

    return LatLngBounds(
        southwest: LatLng(math.min(latitudeStart, latitudeEnd), longitudeStart),
        northeast: LatLng(math.max(latitudeStart, latitudeEnd), longitudeEnd));
  }
  
  Offset _latLngToPixelOffset(LatLng point, LatLngBounds tileBounds, double tileSize, int zoom) {
    final int numTiles = 1 << zoom;
    final double worldTileSize = tileSize * numTiles;

    final double x = (point.longitude + 180.0) / 360.0 * worldTileSize;
    final double sinLatitude = math.sin(point.latitude * math.pi / 180.0);
    final double y = (0.5 - math.log((1.0 + sinLatitude) / (1.0 - sinLatitude)) / (4.0 * math.pi)) * worldTileSize;

    final double tileOriginX = (tileBounds.southwest.longitude + 180.0) / 360.0 * worldTileSize;
    final double tileOriginY = (0.5 - math.log((1.0 + math.sin(tileBounds.northeast.latitude * math.pi / 180.0)) / 
                              (1.0 - math.sin(tileBounds.northeast.latitude * math.pi / 180.0))) / (4.0 * math.pi)) * worldTileSize;
    
    return Offset(x - tileOriginX, y - tileOriginY);
  }
  
  // Limpiar cache si es necesario (por ejemplo, al actualizar los datos)
  void clearCache() {
    _tileCache.clear();
  }
}
