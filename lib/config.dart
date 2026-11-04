/// Connexion au projet Supabase et a PowerSync de Nocta.
/// La cle publique (publishable) peut figurer dans le logiciel :
/// la securite des donnees est assuree par les regles de la base.
/// Ne jamais mettre ici la cle « secret » ni un mot de passe.
class YdsConfig {
  static const supabaseUrl = 'https://jdrnvritfovhebiwkrub.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_j72UqsJabjvsklAoWLG_ZA_oIMKSe2d';

  /// Adresse de l'instance PowerSync (synchronisation hors ligne).
  static const powersyncUrl = 'https://6ae87814b0047aeb6df8f491.powersync.journeyapps.com';

  /// Nocta sert plusieurs clubs. L'equipe se connecte avec le CODE DU CLUB
  /// (memorise une fois sur l'appareil) + un identifiant. Derriere, Supabase
  /// utilise cette adresse interne, propre au club, qui ne recoit jamais d'e-mail.
  static String emailInterne(String identifiant, String codeClub) =>
      '${identifiant.trim().toLowerCase()}@${codeClub.trim().toLowerCase()}.yds-night.invalid';
}
