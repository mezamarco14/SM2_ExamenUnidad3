// File: logicaSms.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class SmsLogic {
  // Check and request location permissions
  Future<bool> _checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false; // Location services are disabled
    }

    // Check permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false; // Permission denied
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false; // Permission permanently denied
    }

    return true; // Permission granted
  }

  // Get current device location
  Future<String?> _getCurrentLocationLink() async {
    try {
      // Check and request permissions
      bool hasPermission = await _checkAndRequestLocationPermission();
      if (!hasPermission) {
        return null; // Return null if permission is not granted or service is disabled
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Create Google Maps link with latitude and longitude
      final double latitude = position.latitude;
      final double longitude = position.longitude;
      final String googleMapsLink = 'https://www.google.com/maps?q=$latitude,$longitude';
      return googleMapsLink;
    } catch (e) {
      debugPrint('Error al obtener la ubicación: $e');
      return null;
    }
  }

  // Send SMS with location link
  Future<void> sendSMS(String phoneNumber, String message, BuildContext context) async {
    final String sanitizedPhoneNumber = phoneNumber.replaceAll(RegExp(r'[()\s]'), '');
    
    // Get current location link
    final String? locationLink = await _getCurrentLocationLink();
    final String fullMessage = locationLink != null
        ? '$message\nUbicación: $locationLink'
        : '$message\nNo se pudo obtener la ubicación actual.';

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: sanitizedPhoneNumber,
      queryParameters: {'body': fullMessage},
    );
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo abrir la app de SMS para $phoneNumber'),
              backgroundColor: Colors.red, 
            ),
          );
        }
        debugPrint('No se pudo lanzar $smsUri');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al intentar enviar SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error al lanzar $smsUri: $e');
    }
  }
}