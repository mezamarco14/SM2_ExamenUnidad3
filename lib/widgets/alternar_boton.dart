import 'package:flutter/material.dart';

class AlternarBoton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;

  const AlternarBoton({
    super.key,
    required this.onPressed,
    this.icon = Icons.layers,
    this.tooltip = 'Alternar vista',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: Colors.black54,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}