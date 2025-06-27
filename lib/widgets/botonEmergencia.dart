import 'package:flutter/material.dart';
import '../screens/pantallaEmergencia.dart';

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});

  void _confirmEmergency(BuildContext context) async {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 380;
    final isTablet = screenSize.width >= 600;

    final double dialogHorizontalPadding = (screenSize.width * 0.05).clamp(15.0, 30.0);
    final double dialogVerticalPadding = (screenSize.height * 0.02).clamp(10.0, 20.0);
    final double titleFontSize = isTablet ? 20 : 18;
    final double contentFontSize = isTablet ? 17 : 16; // Runtime value
    final double actionButtonFontSize = isTablet ? 15 : 14;
    final double iconSize = isTablet ? 30 : 28;

    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.08,
          vertical: 24.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        titlePadding: EdgeInsets.fromLTRB(dialogHorizontalPadding, dialogVerticalPadding, dialogHorizontalPadding, 0),
        contentPadding: EdgeInsets.symmetric(horizontal: dialogHorizontalPadding, vertical: 15.0),
        actionsPadding: EdgeInsets.symmetric(horizontal: dialogHorizontalPadding * 0.75, vertical: dialogVerticalPadding * 0.75),

        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: iconSize),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Confirmar Emergencia',
                style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
           constraints: BoxConstraints(maxHeight: screenSize.height * 0.4),
           child: SingleChildScrollView(
            // *** Corrected: Removed 'const' here ***
            child: Text(
              '¿Estás seguro de que deseas abrir el directorio de números de emergencia?',
              style: TextStyle(fontSize: contentFontSize), // contentFontSize is runtime
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
                fontSize: actionButtonFontSize,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sí, Confirmar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: actionButtonFontSize,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      Navigator.push(
        context,
        // Added const here as EmergencyDirectoryScreen likely can be const
        MaterialPageRoute(builder: (_) => const EmergencyDirectoryScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width >= 600;

    final double buttonHorizontalPadding = (screenSize.width * 0.06).clamp(18.0, 32.0);
    final double buttonVerticalPadding = (screenSize.height * 0.018).clamp(14.0, 20.0);
    final double buttonFontSize = isTablet ? 20 : 18;
    final double buttonIconSize = isTablet ? 28 : 26;

    return ElevatedButton.icon(
      icon: Icon(Icons.sos_rounded, size: buttonIconSize),
      label: Text(
        '¡Emergencia!',
        style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      onPressed: () => _confirmEmergency(context),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.red.shade700,
        padding: EdgeInsets.symmetric(
          horizontal: buttonHorizontalPadding,
          vertical: buttonVerticalPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        elevation: 5.0,
        shadowColor: Colors.red.withAlpha((0.4 * 255).round()),
      ),
    );
  }
}