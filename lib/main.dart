import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/base_locale.dart';
import 'screens/aiguillage.dart';
import 'theme/harem_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: YdsConfig.supabaseUrl,
      publishableKey: YdsConfig.supabasePublishableKey,
    );
    await ouvrirBaseLocale();
  } catch (e) {
    runApp(_ErreurDemarrage(e));
    return;
  }
  runApp(const YdsApp());
}

class YdsApp extends StatelessWidget {
  const YdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YDS Night',
      debugShowCheckedModeBanner: false,
      theme: HaremTheme.theme(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Aiguillage(),
    );
  }
}

class _ErreurDemarrage extends StatelessWidget {
  const _ErreurDemarrage(this.erreur);
  final Object erreur;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: HaremTheme.theme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: HC.rouge),
              const SizedBox(height: 16),
              const Text('YDS Night n\'a pas pu démarrer',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('Fermez complètement l\'application puis rouvrez-la. '
                  'Si le problème continue, envoyez une capture de cet écran.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SelectableText('$erreur', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: HC.gris)),
            ]),
          ),
        ),
      ),
    );
  }
}
