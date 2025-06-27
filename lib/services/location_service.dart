import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Timer? _locationTimer;
  bool _isTracking = false;
  String? _currentUserEmail;

  // Configuración
  static const int _updateIntervalSeconds = 30; // Actualizar cada 30 segundos
  static const double _minimumDistanceMeters = 10; // Solo actualizar si se movió más de 10 metros
  
  Position? _lastKnownPosition;

  /// Registra la entrada del usuario a la app
  Future<void> registerAppEntry() async {
    User? firebaseUser = _auth.currentUser;
    if (firebaseUser?.email == null) return;

    try {
      await _firestore.collection('usuarios').doc(firebaseUser!.email).update({
        'ultimaEntradaApp': FieldValue.serverTimestamp(),
        'ultimoAcceso': FieldValue.serverTimestamp(),
      });
      
      debugPrint('LocationService: Entrada a la app registrada para ${firebaseUser.email}');
    } catch (e) {
      debugPrint('LocationService: Error registrando entrada: $e');
    }
  }

  /// Inicia el seguimiento de ubicación
  Future<bool> startLocationTracking() async {
    if (_isTracking) return true;

    // Obtener email del usuario actual
    User? firebaseUser = _auth.currentUser;
    if (firebaseUser?.email == null) {
      debugPrint('LocationService: No hay usuario autenticado');
      return false;
    }
    _currentUserEmail = firebaseUser!.email;

    // Registrar entrada a la app
    await registerAppEntry();

    // Verificar permisos
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      debugPrint('LocationService: Sin permisos de ubicación');
      return false;
    }

    // Verificar si el servicio está habilitado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: Servicio de ubicación deshabilitado');
      return false;
    }

    _isTracking = true;
    
    // Obtener ubicación inicial
    await _updateUserLocation();
    
    // Iniciar timer para actualizaciones periódicas
    _locationTimer = Timer.periodic(
      const Duration(seconds: _updateIntervalSeconds),
      (timer) => _updateUserLocation(),
    );

    debugPrint('LocationService: Seguimiento iniciado para $_currentUserEmail');
    return true;
  }

  /// Detiene el seguimiento de ubicación
  void stopLocationTracking() {
    if (!_isTracking) return;

    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;
    _lastKnownPosition = null;

    debugPrint('LocationService: Seguimiento detenido');
  }

  /// Verifica y solicita permisos de ubicación
  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Actualiza la ubicación del usuario en Firestore
  Future<void> _updateUserLocation() async {
    if (_currentUserEmail == null) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Verificar si la posición cambió significativamente
      if (_lastKnownPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastKnownPosition!.latitude,
          _lastKnownPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        if (distance < _minimumDistanceMeters) {
          // No actualizar si el movimiento es mínimo
          return;
        }
      }

      // Actualizar en Firestore
      await _firestore.collection('usuarios').doc(_currentUserEmail).update({
        'ubicacionActual': {
          'latitud': position.latitude,
          'longitud': position.longitude,
          'precision': position.accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'ultimaUbicacionActualizacion': FieldValue.serverTimestamp(),
      });

      _lastKnownPosition = position;
      
      debugPrint('LocationService: Ubicación actualizada - Lat: ${position.latitude}, Lng: ${position.longitude}');
      
    } catch (e) {
      debugPrint('LocationService: Error actualizando ubicación: $e');
    }
  }

  /// Obtiene la ubicación actual una sola vez
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) return null;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      debugPrint('LocationService: Error obteniendo ubicación actual: $e');
      return null;
    }
  }

  /// Actualiza la ubicación una sola vez en Firestore
  Future<bool> updateLocationOnce() async {
    if (_currentUserEmail == null) {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser?.email == null) return false;
      _currentUserEmail = firebaseUser!.email;
    }

    Position? position = await getCurrentLocation();
    if (position == null) return false;

    try {
      await _firestore.collection('usuarios').doc(_currentUserEmail).update({
        'ubicacionActual': {
          'latitud': position.latitude,
          'longitud': position.longitude,
          'precision': position.accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'ultimaUbicacionActualizacion': FieldValue.serverTimestamp(),
      });

      debugPrint('LocationService: Ubicación actualizada una vez');
      return true;
    } catch (e) {
      debugPrint('LocationService: Error actualizando ubicación: $e');
      return false;
    }
  }

  /// Verifica si el seguimiento está activo
  bool get isTracking => _isTracking;

  /// Obtiene la última posición conocida
  Position? get lastKnownPosition => _lastKnownPosition;
}
