-- =====================================================================
-- YDS NIGHT · Script 09 · T'enregistrer comme administrateur
-- A lancer APRES avoir cree ton compte administrateur dans Supabase :
--   Authentication > Users > Add user > "Create new user"
--   (mets ton e-mail et un mot de passe ; coche "Auto Confirm User").
--
-- Ensuite, remplace VOTRE_EMAIL_ICI ci-dessous par ce meme e-mail, puis "Run".
-- C'est avec ce compte que tu ouvriras l'espace admin de YDS Night
-- (creer des clubs, enregistrer les paiements, suspendre/reactiver).
-- =====================================================================

insert into public.platform_admins (user_id)
select id from auth.users where lower(email) = lower(trim('VOTRE_EMAIL_ICI'))
on conflict do nothing;

select case when count(*) > 0 then 'OK : administrateur enregistre'
            else 'ATTENTION : e-mail introuvable. Cree d''abord le compte dans Authentication > Users, '
                 || 'puis remplace VOTRE_EMAIL_ICI et relance ce script.'
       end as resultat
from public.platform_admins;
