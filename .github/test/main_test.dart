import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:SM2_ExamenUnidad3/lib/services/auth_service.dart'; 

class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}

void main() {
  group('AuthService Firebase Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser(
        uid: 'testuid',
        email: 'test@example.com',
        displayName: 'Test User',
        photoURL: 'http://photo.url',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);
      AuthService.dispose(); // Para limpiar cualquier controlador previo si se reutiliza
    });

    test('signInWithEmailAndPassword retorna UserCredential válido', () async {
      final result = await mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      expect(result.user?.email, 'test@example.com');
    });

    test('signOut cierra la sesión correctamente', () async {
      await mockAuth.signOut();
      expect(mockAuth.currentUser, isNull);
    });

    test('signInWithGoogle simulado con mocks', () async {
      final googleSignIn = MockGoogleSignIn();
      final googleUser = MockGoogleSignInAccount();
      final googleAuth = MockGoogleSignInAuthentication();

      when(googleSignIn.signIn()).thenAnswer((_) async => googleUser);
      when(googleUser.authentication).thenAnswer((_) async => googleAuth);
      when(googleAuth.accessToken).thenReturn('fake_access_token');
      when(googleAuth.idToken).thenReturn('fake_id_token');

      final credential = GoogleAuthProvider.credential(
        accessToken: 'fake_access_token',
        idToken: 'fake_id_token',
      );

      final userCredential = await mockAuth.signInWithCredential(credential);
      expect(userCredential.user, isNotNull);
    });
  });
}

