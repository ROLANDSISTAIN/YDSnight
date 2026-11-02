-- =====================================================================
-- YDS NIGHT · Script 07 · Acces de PowerSync (synchronisation hors ligne)
-- AVANT de lancer : remplace CHOISIS_UN_MOT_DE_PASSE par un mot de passe
-- long (lettres + chiffres), que tu recopieras ensuite dans PowerSync.
-- Ne le partage avec personne.
--
-- Le cloisonnement par club se fait dans les regles de synchronisation
-- de PowerSync (fichier POWERSYNC/sync_rules.yaml) : chaque appareil ne
-- recoit que les lignes de SON club (bucket par club_id), et la serveuse
-- seulement ses propres notes.
-- =====================================================================

do $$
begin
  create role powersync_role with replication bypassrls login password 'CHOISIS_UN_MOT_DE_PASSE';
exception when duplicate_object then
  raise notice 'powersync_role existe deja';
end $$;

grant select on all tables in schema public to powersync_role;
alter default privileges in schema public grant select on tables to powersync_role;

do $$
begin
  create publication powersync for all tables;
exception when duplicate_object then
  raise notice 'La publication powersync existe deja';
end $$;
