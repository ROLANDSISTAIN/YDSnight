-- =====================================================================
-- YDS NIGHT · Script 10 · Correctif : colonne id sur les reglages
-- A lancer UNE fois si tu as deja execute le script 01 dans sa premiere
-- version (ou tu peux simplement relancer le 01 corrige sur une base vide).
--
-- PowerSync a besoin d'une colonne « id » comme cle primaire sur chaque
-- table. La table settings etait la seule a ne pas en avoir. Sans donnees,
-- cette correction est sans risque.
-- =====================================================================

do $$
begin
  -- Ajoute la colonne id si elle manque
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'settings' and column_name = 'id') then
    alter table public.settings add column id uuid not null default gen_random_uuid();
    -- club_id n'est plus la cle primaire mais reste unique
    alter table public.settings drop constraint if exists settings_pkey;
    alter table public.settings add primary key (id);
    alter table public.settings add constraint settings_club_id_key unique (club_id);
    raise notice 'settings : colonne id ajoutee, club_id rendu unique';
  else
    raise notice 'settings : colonne id deja presente, rien a faire';
  end if;
end $$;

notify pgrst, 'reload schema';
