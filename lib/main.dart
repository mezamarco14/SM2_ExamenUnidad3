import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';
import 'screen_principal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();
  AuthService.listenForTokenRefresh();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlertaTacna',
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF1E3A8A),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF3B82F6),
        ),
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w700),
          displayMedium: TextStyle(fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontWeight: FontWeight.w400),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const ScreenPrincipal(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    AuthService.authStateChanges.listen((isLoggedIn) {
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
        });
      }
    });
  }

  Future<void> _checkAuthState() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        ),
      );
    }
    if (_isLoggedIn!) {
      return const ScreenPrincipal();
    }
    return const LoginScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _backgroundAnimationController;
  late AnimationController _contentAnimationController;
  late AnimationController _particleAnimationController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _particleAnimation;
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();
  final TextEditingController _emailLoginController = TextEditingController();
  final TextEditingController _passwordLoginController = TextEditingController();
  final TextEditingController _nameRegisterController = TextEditingController();
  final TextEditingController _emailRegisterController = TextEditingController();
  final TextEditingController _passwordRegisterController = TextEditingController();
  bool _isLoggingIn = false;
  bool _isRegistering = false;
  bool _isGoogleSignIn = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final List<Map<String, dynamic>> _heroContent = [
    {
      'icon': Icons.shield_outlined,
      'title': 'Seguridad Inteligente',
      'subtitle': 'Proteccion comunitaria con tecnologia avanzada de alertas en tiempo real.',
      'gradient': [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
    },
    {
      'icon': Icons.location_on_outlined,
      'title': 'Alertas de Proximidad',
      'subtitle': 'Recibe notificaciones automaticas cuando te acerques a zonas de riesgo.',
      'gradient': [const Color(0xFF7C3AED), const Color(0xFFA855F7)],
    },
    {
      'icon': Icons.people_outline,
      'title': 'Red Colaborativa',
      'subtitle': 'Unete a tu comunidad para crear un entorno mas seguro para todos.',
      'gradient': [const Color(0xFF059669), const Color(0xFF10B981)],
    },
  ];
  int _currentContentIndex = 0;

  final Uri _privacyPolicyUrl = Uri.parse('https://sites.google.com/view/mundotechdevs-alerta-tacna/');
  final Uri _termsUrl = Uri.parse('https://sites.google.com/view/alerta-tacna-termofuse/');
  final Uri _deleteAccountUrl = Uri.parse('https://sites.google.com/view/eliminarcuentaalerta/p%C3%A1gina-principal');


  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startContentRotation();
  }

  void _initializeAnimations() {
    _tabController = TabController(length: 2, vsync: this);
    _backgroundAnimationController = AnimationController(duration: const Duration(seconds: 20), vsync: this,);
    _contentAnimationController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this,);
    _particleAnimationController = AnimationController(duration: const Duration(seconds: 15), vsync: this,);
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0,).animate(CurvedAnimation(parent: _backgroundAnimationController, curve: Curves.linear,));
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0,).animate(CurvedAnimation(parent: _contentAnimationController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut),));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero,).animate(CurvedAnimation(parent: _contentAnimationController, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0,).animate(CurvedAnimation(parent: _contentAnimationController, curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),));
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0,).animate(_particleAnimationController);
    _backgroundAnimationController.repeat();
    _particleAnimationController.repeat();
    _contentAnimationController.forward();
  }

  void _startContentRotation() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _currentContentIndex = (_currentContentIndex + 1) % _heroContent.length;
        });
        _startContentRotation();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _backgroundAnimationController.dispose();
    _contentAnimationController.dispose();
    _particleAnimationController.dispose();
    _emailLoginController.dispose();
    _passwordLoginController.dispose();
    _nameRegisterController.dispose();
    _emailRegisterController.dispose();
    _passwordRegisterController.dispose();
    super.dispose();
  }
  
  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showErrorSnackBar('No se pudo abrir el enlace.');
    }
  }

  Future<void> _login() async {
    if (_loginFormKey.currentState!.validate()) {
      setState(() => _isLoggingIn = true);
      String email = _emailLoginController.text.trim();
      try {
        String password = _passwordLoginController.text.trim();
        QuerySnapshot querySnapshot = await _firestore
            .collection('usuarios')
            .where('correo', isEqualTo: email)
            .where('password', isEqualTo: password)
            .get();
        if (querySnapshot.docs.isNotEmpty && mounted) {
          await AuthService.saveCredentialLogin(email);
          await _startUserServices(email);
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        } else if (mounted) {
          _showErrorSnackBar('Credenciales incorrectas');
        }
      } catch (e) {
        if (mounted) _showErrorSnackBar('Error al iniciar sesion: $e');
      } finally {
        if (mounted) setState(() => _isLoggingIn = false);
      }
    }
  }

  Future<void> _register() async {
    if (_registerFormKey.currentState!.validate()) {
      setState(() => _isRegistering = true);
      String email = _emailRegisterController.text.trim();
      try {
        String name = _nameRegisterController.text.trim();
        String password = _passwordRegisterController.text.trim();
        QuerySnapshot existingUser = await _firestore
            .collection('usuarios')
            .where('correo', isEqualTo: email)
            .get();
        if (existingUser.docs.isNotEmpty) {
          if (mounted) _showErrorSnackBar('El usuario ya existe');
          setState(() => _isRegistering = false);
          return;
        }
        await _firestore.collection('usuarios').doc(email).set({
          'nombre': name,
          'correo': email,
          'password': password,
          'notificacionesActivas': true,
          'radioAlerta': 500,
          'sensibilidad': 'Medio',
          'fechaCreacion': FieldValue.serverTimestamp(),
          'ultimoAcceso': FieldValue.serverTimestamp(),
          'loginMethod': 'credentials',
        });
        await AuthService.updateUserFCMToken(email);
        if (mounted) {
          _showSuccessSnackBar('Usuario registrado exitosamente. Por favor, inicia sesion.');
          _clearRegisterForm();
          _tabController.animateTo(0);
        }
      } catch (e) {
        if (mounted) _showErrorSnackBar('Error al registrar usuario: $e');
      } finally {
        if (mounted) setState(() => _isRegistering = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleSignIn = true);
    try {
      final userCredential = await AuthService.signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        await _startUserServices(userCredential.user!.email!);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al iniciar sesion con Google: ${AuthService.getAuthErrorMessage(e)}');
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleSignIn = false);
      }
    }
  }

  Future<void> _startUserServices(String userEmail) async {
    await _locationService.startLocationTracking();
  }

  void _clearRegisterForm() {
    _nameRegisterController.clear();
    _emailRegisterController.clear();
    _passwordRegisterController.clear();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message)),],),
        backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message)),],),
        backgroundColor: const Color(0xFF059669), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentContent = _heroContent[_currentContentIndex];
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_backgroundAnimation, _particleAnimation,]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF0F172A), const Color(0xFF1E293B), _backgroundAnimation.value * 0.5,)!,
                  Color.lerp(const Color(0xFF1E293B), const Color(0xFF334155), _backgroundAnimation.value * 0.3,)!,
                  Color.lerp(currentContent['gradient'][0], currentContent['gradient'][1], _backgroundAnimation.value * 0.2,)!,
                ],
                stops: [0.0, 0.5 + (_backgroundAnimation.value * 0.3), 1.0,],
              ),
            ),
            child: Stack(
              children: [
                ...List.generate(20, (index) {
                  final offset = Offset((index * 50.0) % MediaQuery.of(context).size.width, (index * 80.0) % MediaQuery.of(context).size.height,);
                  return Positioned(
                    left: offset.dx + (_particleAnimation.value * 100) - 50,
                    top: offset.dy + (_particleAnimation.value * 200) - 100,
                    child: Opacity(
                      opacity: 0.1 + (_particleAnimation.value * 0.1),
                      child: Container(
                        width: 4 + (index % 3) * 2, height: 4 + (index % 3) * 2,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),),
                      ),
                    ),
                  );
                }),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(flex: 4, child: _buildHeroSection(currentContent),),
                      Expanded(flex: 7, child: _buildFormSection(),),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(Map<String, dynamic> content) {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation), child: child,),);
                  },
                  child: Container(
                    key: ValueKey(_currentContentIndex), width: 100, height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: content['gradient'], begin: Alignment.topLeft, end: Alignment.bottomRight,),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: content['gradient'][0].withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10),),],
                    ),
                    child: Icon(content['icon'], size: 50, color: Colors.white,),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Text(content['title'], key: ValueKey('${_currentContentIndex}_title'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5, height: 1.2,), textAlign: TextAlign.center,),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Text(content['subtitle'], key: ValueKey('${_currentContentIndex}_subtitle'), style: TextStyle(fontSize: 14, color: Colors.grey.shade300, fontWeight: FontWeight.w400, height: 1.4,), textAlign: TextAlign.center,),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_heroContent.length, (index) {
                    return AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), width: index == _currentContentIndex ? 24 : 8, height: 8, decoration: BoxDecoration(color: index == _currentContentIndex ? Colors.white : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(4),),);
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32),),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -5),),],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.8), borderRadius: BorderRadius.circular(16),),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],), borderRadius: BorderRadius.circular(16),),
              labelColor: Colors.white, unselectedLabelColor: Colors.grey.shade400, dividerColor: Colors.transparent, labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16,),
              tabs: const [Tab(text: 'Iniciar Sesion'), Tab(text: 'Registrarse'),],
            ),
          ),
          Expanded(child: TabBarView(controller: _tabController, children: [_buildLoginForm(), _buildRegisterForm(),],),),
          _buildLegalLinks(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildLegalLinks(BuildContext context) {
    final linkStyle = TextStyle(
      color: Colors.blue.shade300,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: Colors.blue.shade300,
    );
  
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 4,
        spacing: 8,
        children: <Widget>[
          Text.rich(
            textAlign: TextAlign.center,
            TextSpan(
              text: 'Al continuar, aceptas nuestra ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              children: <TextSpan>[
                TextSpan(
                  text: 'Politica de Privacidad',
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(_privacyPolicyUrl),
                ),
                const TextSpan(text: ' y nuestros '),
                TextSpan(
                  text: 'Terminos y Condiciones',
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(_termsUrl),
                ),
                const TextSpan(text: '. '),
                 TextSpan(
                  text: 'Eliminar mi cuenta.',
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(_deleteAccountUrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            _buildGoogleSignInButton(),
            const SizedBox(height: 24),
            _buildDivider(),
            const SizedBox(height: 24),
            _buildTextField(controller: _emailLoginController, hintText: 'tu@email.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Por favor, ingresa tu correo';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Ingresa un correo valido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(controller: _passwordLoginController, hintText: 'Tu contrasena', icon: Icons.lock_outline, obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Por favor, ingresa tu contrasena';
                return null;
              },
            ),
            const SizedBox(height: 32),
            _buildPrimaryButton(text: 'Iniciar Sesion', isLoading: _isLoggingIn, onPressed: _login,),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            _buildTextField(controller: _nameRegisterController, hintText: 'Tu nombre completo', icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Por favor, ingresa tu nombre';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(controller: _emailRegisterController, hintText: 'tu@email.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Por favor, ingresa tu correo';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Ingresa un correo valido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(controller: _passwordRegisterController, hintText: 'Crea una contrasena segura', icon: Icons.lock_outline, obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Por favor, ingresa una contrasena';
                if (value.length < 6) return 'La contrasena debe tener al menos 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 32),
            _buildPrimaryButton(text: 'Crear Cuenta', isLoading: _isRegistering, onPressed: _register,),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      width: double.infinity, height: 56,
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF1976D2)],), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF4285F4).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4),),],),
      child: ElevatedButton.icon(
        onPressed: _isGoogleSignIn ? null : _signInWithGoogle,
        icon: _isGoogleSignIn ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white),),) : Image.network('https://developers.google.com/identity/images/g-logo.png', width: 24, height: 24,),
        label: Text(_isGoogleSignIn ? 'Iniciando sesion...' : 'Continuar con Google', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white,),),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),),),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, required IconData icon, bool obscureText = false, TextInputType? keyboardType, String? Function(String?)? validator,}) {
    return TextFormField(
      controller: controller, obscureText: obscureText, keyboardType: keyboardType, style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText, hintStyle: TextStyle(color: Colors.grey.shade500), prefixIcon: Icon(icon, color: Colors.grey.shade500), filled: true, fillColor: const Color(0xFF1E293B).withOpacity(0.7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none,),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade800.withOpacity(0.5)),),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDC2626)),),
        contentPadding: const EdgeInsets.all(20),
      ),
      validator: validator,
    );
  }

  Widget _buildPrimaryButton({required String text, required bool isLoading, required VoidCallback onPressed,}) {
    return Container(
      width: double.infinity, height: 56,
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4),),],),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),),),
        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2,) : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white,),),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade700.withOpacity(0.5))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('o continua con correo', style: TextStyle(color: Colors.grey.shade400, fontSize: 14,),),),
        Expanded(child: Divider(color: Colors.grey.shade700.withOpacity(0.5))),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF3B82F6).withOpacity(0.1), const Color(0xFF1D4ED8).withOpacity(0.1),],), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3),),),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20,), const SizedBox(width: 12),
          Expanded(child: Text('Al registrarte, se activaran automaticamente las alertas de proximidad.', style: TextStyle(color: Colors.blue.shade200, fontSize: 12,),),),
        ],
      ),
    );
  }
}