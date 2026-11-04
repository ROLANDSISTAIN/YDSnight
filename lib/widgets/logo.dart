import 'package:flutter/material.dart';

import '../theme/harem_theme.dart';

/// Logo de Nocta : une lune et le nom, en cyan.
class Logo extends StatelessWidget {
  const Logo({super.key, this.taille = 40, this.slogan = true});
  final double taille;

  /// Gardé pour compatibilité des appels ; Nocta n'affiche pas de slogan
  /// (le logiciel sert aussi bien aux boîtes de nuit qu'aux bars).
  final bool slogan;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.dark_mode, color: HC.or, size: taille * 0.62),
        SizedBox(height: taille * 0.16),
        Text('NOCTA',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: taille,
                fontWeight: FontWeight.w800,
                letterSpacing: taille * 0.22,
                color: HC.or,
                height: 1.1)),
      ],
    );
  }
}
