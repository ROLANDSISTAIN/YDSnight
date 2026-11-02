import 'dart:convert';

import 'appareil.dart' as appareil;

/// Le club retenu sur cet appareil (saisi une fois lors de la mise en place).
/// L'equipe se connecte ensuite avec seulement identifiant + code PIN.
class ClubLocal {
  const ClubLocal({required this.code, required this.nom});
  final String code;
  final String nom;
}

const _fichier = 'club.json';
ClubLocal? _cache;

/// Le club enregistre sur cet appareil, ou null s'il n'y en a pas encore.
Future<ClubLocal?> clubEnregistre() async {
  if (_cache != null) return _cache;
  final brut = await appareil.lireDonnee(_fichier);
  if (brut == null) return null;
  try {
    final j = jsonDecode(brut) as Map<String, dynamic>;
    final code = (j['code'] as String?)?.trim();
    if (code == null || code.isEmpty) return null;
    return _cache = ClubLocal(code: code, nom: (j['nom'] as String?) ?? '');
  } catch (_) {
    return null;
  }
}

Future<void> enregistrerClub(String code, String nom) async {
  final c = ClubLocal(code: code.trim().toLowerCase(), nom: nom);
  _cache = c;
  await appareil.ecrireDonnee(_fichier, jsonEncode({'code': c.code, 'nom': c.nom}));
}

Future<void> oublierClub() async {
  _cache = null;
  await appareil.effacerDonnee(_fichier);
}
