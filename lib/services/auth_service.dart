import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userEmailKey = 'user_email';
  static const String _loginMethodKey = 'login_method';

  static final _authStateController = StreamController<bool>.broadcast();
  static Stream<bool> get authStateChanges => _authStateController.stream;
  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await saveGoogleLogin(userCredential.user!.email!);
      }
      return userCredential;
    } catch (e) {
      print('Error en login con Google: $e');
      rethrow;
    }
  }

  static Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await saveCredentialLogin(email.trim());
      }
      return userCredential;
    } catch (e) {
      print('Error en login con email: $e');
      rethrow;
    }
  }

  static Future<UserCredential?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential;
    } catch (e) {
      print('Error en login anonimo: $e');
      rethrow;
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<String?> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  static Future<String?> getLoginMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_loginMethodKey);
  }

  static Future<void> saveCredentialLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_loginMethodKey, 'credentials');
    _authStateController.add(true);
    await updateUserFCMToken(email);
  }

  static Future<void> saveGoogleLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_loginMethodKey, 'google');
    _authStateController.add(true);
  }

  static Future<UserCredential?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await saveCredentialLogin(email.trim());
      }
      return userCredential;
    } catch (e) {
      print('Error en registro: $e');
      rethrow;
    }
  }

  static Future<void> _saveUserToFirestore(User user) async {
    if (user.email == null) {
      print("Error: user.email es null en _saveUserToFirestore");
      return;
    }
    try {
      Map<String, dynamic> userDataToSave = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email!.split('@').first,
        'photoURL': user.photoURL ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
      };
      final userDocRef = _firestore.collection('usuarios').doc(user.email!);
      final docSnapshot = await userDocRef.get();
      if (!docSnapshot.exists) {
        userDataToSave.addAll({
          'notificacionesActivas': true,
          'radioAlerta': 500,
          'sensibilidad': 'Medio',
          'fechaCreacion': FieldValue.serverTimestamp(),
          'loginMethod': 'firebase_auth',
        });
      } else {
         userDataToSave['loginMethod'] = 'firebase_auth';
      }
      
      await userDocRef.set(userDataToSave, SetOptions(merge: true));
      print('Usuario ${user.email} guardado/actualizado en Firestore.');
      await updateUserFCMToken(user.email!);
    } catch (e) {
      print('Error guardando usuario en Firestore: $e');
    }
  }

  static Future<void> updateUserFCMToken(String userEmail) async {
    if (userEmail.isEmpty) {
      print('Error: userEmail esta vacio, no se puede actualizar FCM token.');
      return;
    }
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('usuarios').doc(userEmail).set({
          'fcmToken': token,
          'tokenActualizacion': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('FCM Token guardado/actualizado para $userEmail: $token');
      } else {
        print('No se pudo obtener el FCM token para $userEmail.');
      }
    } catch (e) {
      print('Error al guardar/actualizar FCM token para $userEmail: $e');
    }
  }

  static void listenForTokenRefresh() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print("FCM Token se ha refrescado: $newToken");
      String? userEmail = await getCurrentUserEmail();
      if (userEmail != null && userEmail.isNotEmpty) {
        await updateUserFCMToken(userEmail);
      }
    });
  }

  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginMethod = prefs.getString(_loginMethodKey);
      await _auth.signOut();
      if (loginMethod == 'google') {
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          print('Error cerrando sesion de Google: $e');
        }
      }
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_loginMethodKey);
      _authStateController.add(false);
      print('Sesion cerrada exitosamente');
    } catch (e) {
      print('Error cerrando sesion: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_loginMethodKey);
      _authStateController.add(false);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final email = await getCurrentUserEmail();
      if (email == null) return null;
      final DocumentSnapshot userDoc = await _firestore
          .collection('usuarios')
          .doc(email)
          .get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      return null;
    }
  }

  static bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  static String getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found': return 'No se encontro una cuenta con este email.';
        case 'wrong-password': return 'Contrasena incorrecta.';
        case 'email-already-in-use': return 'Ya existe una cuenta con este email.';
        case 'weak-password': return 'La contrasena es muy debil.';
        case 'invalid-email': return 'El formato del email es invalido.';
        case 'user-disabled': return 'Esta cuenta ha sido deshabilitada.';
        case 'too-many-requests': return 'Demasiados intentos fallidos. Intenta mas tarde.';
        case 'network-request-failed': return 'Error de conexion. Verifica tu internet.';
        default: return 'Error de autenticacion: ${error.message}';
      }
    }
    return 'Error desconocido: $error';
  }

  static void dispose() {
    _authStateController.close();
  }
}