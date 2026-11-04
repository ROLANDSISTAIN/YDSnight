import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/club_local.dart';
import '../services/erreurs.dart';
import '../theme/harem_theme.dart';
import '../widgets/logo.dart';

/// Mise en place de l'appareil : on saisit une fois le CODE DU CLUB
/// (fourni par Nocta). L'appareil le retient ensuite.
class EcranCodeClub extends StatefulWidget {
  const EcranCodeClub({super.key, required this.onEnregistre});
  final VoidCallback onEnregistre;

  @override
  State<EcranCodeClub> createState() => _EcranCodeClubState();
}

class _EcranCodeClubState extends State<EcranCodeClub> {
  final _code = TextEditingController();
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final code = _code.text.trim().toLowerCase();
    if (code.isEmpty) return setState(() => _erreur = 'Entrez le code du club.');
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final res = await Supabase.instance.client.rpc('club_by_code', params: {'p_code': code});
      final data = (res is Map) ? res : null;
      if (data == null || data['trouve'] != true) {
        setState(() => _erreur = 'Code du club inconnu. Vérifiez-le auprès de Nocta.');
        return;
      }
      await enregistrerClub(data['code'] as String, (data['nom'] as String?) ?? '');
      widget.onEnregistre();
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Logo(taille: 46),
                  const SizedBox(height: 36),
                  const Text('Mise en place de l\'appareil',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text(
                    'Entrez le code de votre club (fourni par Nocta). '
                    'Vous ne le saisirez qu\'une seule fois sur cet appareil.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: HC.gris),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))],
                    onSubmitted: (_) => _valider(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 4),
                    decoration: const InputDecoration(
                      labelText: 'Code du club',
                      hintText: 'ex. k7m3qp',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 12),
                    Text(_erreur!, style: const TextStyle(color: HC.rouge)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _envoi ? null : _valider,
                    child: _envoi
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Continuer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
