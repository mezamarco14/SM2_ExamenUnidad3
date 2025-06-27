import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../screens/report_detail_screen.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Usuario otorgo permisos para notificaciones');
      await _setupNotificationHandlers();
    } else {
      print('Usuario denego permisos para notificaciones');
    }
  }

  static Future<void> _setupNotificationHandlers() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notificacion recibida en foreground: ${message.notification?.title} - ${message.data}');
      _showInAppNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notificacion tocada desde background: ${message.data}');
      _handleNotificationTap(message);
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('App abierta desde notificacion (initialMessage): ${initialMessage.data}');
      Future.delayed(const Duration(milliseconds: 500), () {
         _handleNotificationTap(initialMessage);
      });
    }
  }

  static void _showInAppNotification(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context != null && message.notification != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.notification!.title ?? 'Nueva Alerta',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(message.notification!.body ?? 'Tienes un nuevo reporte cerca'),
            ],
          ),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _handleNotificationTap(message);
            }
          ),
          duration: const Duration(seconds: 7),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final reportIdFromPayload = message.data['report_id'] as String?;
    print("NotificationService: _handleNotificationTap. report_id del payload: '$reportIdFromPayload'");

    if (reportIdFromPayload != null && reportIdFromPayload.isNotEmpty) {
      final currentState = navigatorKey.currentState;
      if (currentState != null) {
          print("NotificationService: Navegando a ReportDetailsScreen con ID: '$reportIdFromPayload'");
          currentState.push(
            MaterialPageRoute(
              builder: (_) => ReportDetailsScreen(reportId: reportIdFromPayload),
            ),
          );
      } else {
          print("NotificationService: navigatorKey.currentState es null. No se puede navegar.");
      }
    } else {
      print('NotificationService: report_id NO encontrado en el payload de datos o esta vacio.');
      final context = navigatorKey.currentContext;
      if (context != null) {
        _showErrorSnackBar(context, 'Informacion de reporte no disponible en la notificacion.');
      }
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error obteniendo token FCM: $e');
      return null;
    }
  }
}