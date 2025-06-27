import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/alert_settings_screen.dart';
import '../screens/noticias_screen.dart';
import '../screens/fake_report_map_screen.dart';
import '../screens/reporteformulario.dart';
import '../services/auth_service.dart';

class BarraLateral extends StatefulWidget {
  final VoidCallback onLogout;

  const BarraLateral({super.key, required this.onLogout});

  @override
  State<BarraLateral> createState() => _BarraLateralState();
}

class _BarraLateralState extends State<BarraLateral> with TickerProviderStateMixin {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Paleta de colores azul
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color lightBlue = Color(0xFF42A5F5);
  static const Color darkBlue = Color(0xFF0D47A1);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _loadUserData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    _currentUser = AuthService.currentUser;

    if (_currentUser == null) {
      final email = await AuthService.getCurrentUserEmail();
      final userData = await AuthService.getCurrentUserData();

      if (email != null && userData != null) {
        _userData = userData;
        _userData!['email'] = email;
      }
    } else {
      _userData = await AuthService.getCurrentUserData();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              darkBlue,
              primaryBlue,
              lightBlue,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildUserHeader(),
              Expanded(
                child: _buildMenuItems(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildProfileAvatar(),
            const SizedBox(height: 16),
            _buildUserInfo(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 45,
        backgroundColor: Colors.white,
        backgroundImage: _currentUser?.photoURL != null
            ? NetworkImage(_currentUser!.photoURL!)
            : null,
        child: _currentUser?.photoURL == null
            ? Text(
                _getInitials(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              )
            : null,
      ),
    );
  }

  String _getInitials() {
    final name = _currentUser?.displayName ?? 
                 _userData?['displayName'] ?? 
                 _userData?['nombre'] ?? 
                 'Usuario';
    
    // Limpiar el nombre y dividir en palabras no vacías
    final words = name.trim().split(' ').where((String word) => word.isNotEmpty).toList();
    
    if (words.length >= 2) {
      // Si hay al menos 2 palabras, tomar la primera letra de cada una
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      // Si hay solo una palabra
      final firstWord = words[0];
      if (firstWord.length >= 2) {
        // Si la palabra tiene 2 o más caracteres, tomar los primeros 2
        return firstWord.substring(0, 2).toUpperCase();
      } else if (firstWord.isNotEmpty) {
        // Si la palabra tiene solo 1 carácter
        return firstWord[0].toUpperCase();
      }
    }
    // Fallback si todo falla
    return 'U';
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        Text(
          _currentUser?.displayName ?? 
          _userData?['displayName'] ?? 
          _userData?['nombre'] ?? 
          'Usuario',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          _currentUser?.email ?? 
          _userData?['email'] ?? 
          _userData?['correo'] ?? 
          'Sin email',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMenuItems() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        ListTile(
          leading: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
          title: const Text('Reportar Incidente (Formulario)', 
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          onTap: () {
            Navigator.pop(context); 
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReporteFormularioScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: Icon(Icons.article_outlined, color: Colors.teal.shade700),
          title: const Text(
            'Noticias',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          onTap: () {
            Navigator.pop(context); // Cierra el drawer
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NoticiasScreen(), // Navega a la pantalla de noticias
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: Icon(Icons.settings_outlined, color: Colors.green.shade700),
          title: const Text('Configuración de Alertas', 
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          onTap: () {
            Navigator.pop(context); 
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AlertSettingsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: Icon(Icons.map_outlined, color: Colors.purple.shade700),
          title: const Text('Generar Reportes (Mapa)', 
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          onTap: () {
            Navigator.pop(context); 
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FakeReportMapScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Cerrar Sesión'),
          onTap: widget.onLogout,
        ),
      ],
    );
  }
}
