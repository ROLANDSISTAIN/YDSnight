import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/base_locale.dart';
import '../data/membre.dart';
import '../services/club_local.dart';
import '../services/erreurs.dart';
import '../theme/harem_theme.dart';
import '../widgets/etat_synchro.dart';
import '../widgets/logo.dart';
import 'code_club.dart';
import 'connexion.dart';
import 'gestion/gestion.dart';
import 'serveuse/accueil_serveuse.dart';

/// Choisit l'ecran : mise en place du club, connexion, puis l'espace qui
/// correspond au role de la personne. Verifie aussi l'abonnement du club.
class Aiguillage extends StatefulWidget {
  const Aiguillage({super.key});

  @override
  State<Aiguillage> createState() => _AiguillageState();
}

class _AiguillageState extends State<Aiguillage> {
  late Future<ClubLocal?> _club = clubEnregistre();

  void _rechargerClub() => setState(() => _club = clubEnregistre());

  Future<void> _changerClub() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    await oublierClub();
    _rechargerClub();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClubLocal?>(
      future: _club,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _Splash();
        }
        final club = snap.data;
        if (club == null) {
          return EcranCodeClub(onEnregistre: _rechargerClub);
        }
        return _PorteConnexion(club: club, onChangerClub: _changerClub);
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Logo(taille: 36, slogan: false)));
}

/// Porte de connexion : branchee sur la session Supabase.
class _PorteConnexion extends StatelessWidget {
  const _PorteConnexion({required this.club, required this.onChangerClub});
  final ClubLocal club;
  final VoidCallback onChangerClub;

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final session = auth.currentSession;
        if (session == null) {
          return EcranConnexion(club: club, onChangerClub: onChangerClub);
        }
        return _Chargement(key: ValueKey(session.user.id));
      },
    );
  }
}

class _Entree {
  const _Entree(this.membre, this.abonnementBloque);
  final Membre membre;
  final bool abonnementBloque;
}

class _Chargement extends StatefulWidget {
  const _Chargement({super.key});

  @override
  State<_Chargement> createState() => _ChargementState();
}

class _ChargementState extends State<_Chargement> {
  late Future<_Entree?> _donnees = _charger();

  static Future<_Entree?> _charger() async {
    await attendrePremiereSynchro();
    var m = await Membre.charger();
    // Juste apres la connexion, la fiche peut arriver quelques secondes apres le reste.
    for (var i = 0; m == null && i < 10; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      m = await Membre.charger();
    }
    if (m == null) return null;

    // Etat de l'abonnement du club. En cas d'echec (hors ligne), on n'empeche
    // pas l'usage : le blocage dur est de toute facon applique par le serveur.
    var bloque = false;
    try {
      final res = await Supabase.instance.client.rpc('subscription_status');
      if (res is Map && res['bloquant'] == true) bloque = true;
    } catch (_) {}
    return _Entree(m, bloque);
  }

  void _recharger() => setState(() => _donnees = _charger());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Entree?>(
      future: _donnees,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Logo(taille: 36, slogan: false),
                SizedBox(height: 32),
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Chargement des données du club…', style: TextStyle(color: HC.gris)),
              ]),
            ),
          );
        }
        final entree = snap.data;
        if (snap.hasError || entree == null) {
          return _MessagePleinEcran(
            icone: Icons.error_outline,
            couleur: HC.rouge,
            texte: snap.hasError
                ? messageErreur(snap.error!)
                : 'Ce compte n\'est pas reconnu ou a été désactivé. Adressez-vous au patron.',
            boutons: [
              SizedBox(width: 240, child: FilledButton(onPressed: _recharger, child: const Text('Réessayer'))),
              TextButton(onPressed: () => deconnexion(context), child: const Text('Se déconnecter')),
            ],
          );
        }

        if (entree.abonnementBloque) {
          return _MessagePleinEcran(
            icone: Icons.lock_clock,
            couleur: HC.rouge,
            titre: 'Abonnement terminé',
            texte: entree.membre.estPatron
                ? 'L\'abonnement de votre club est arrivé à échéance. '
                  'Contactez YDS Night pour le renouveler et réactiver le logiciel.'
                : 'Le logiciel est en pause : l\'abonnement du club doit être renouvelé. '
                  'Prévenez le patron.',
            boutons: [
              SizedBox(width: 240, child: FilledButton(onPressed: _recharger, child: const Text('Réessayer'))),
              TextButton(onPressed: () => deconnexion(context), child: const Text('Se déconnecter')),
            ],
          );
        }

        final m = entree.membre;
        return m.estServeuse ? AccueilServeuse(membre: m) : EspaceGestion(membre: m);
      },
    );
  }
}

class _MessagePleinEcran extends StatelessWidget {
  const _MessagePleinEcran({
    required this.icone,
    required this.couleur,
    required this.texte,
    this.titre,
    this.boutons = const [],
  });
  final IconData icone;
  final Color couleur;
  final String texte;
  final String? titre;
  final List<Widget> boutons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icone, color: couleur, size: 44),
            const SizedBox(height: 16),
            if (titre != null) ...[
              Text(titre!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 10),
            ],
            Text(texte, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ...boutons,
          ]),
        ),
      ),
    );
  }
}
