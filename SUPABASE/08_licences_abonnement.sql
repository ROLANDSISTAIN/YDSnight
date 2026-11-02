-- =====================================================================
-- YDS NIGHT · Script 08 · Licences, abonnement et espace admin
-- A coller dans Supabase > SQL Editor > New query, puis « Run ».
--
-- Modele : un client = un club. L'abonnement est porte par le club.
--   - C'est TOI (admin de YDS Night) qui crees le club et son patron, et
--     fixes la date de fin d'abonnement. Tu donnes au client son CODE DE CLUB.
--   - Tarifs par defaut : 25 000 FCFA / mois. (Installation 200 000 FCFA :
--     geste commercial hors logiciel, note comme tu veux.)
--   - 7 jours avant la fin : avertissement. Apres la fin : 7 jours de grace
--     (le logiciel marche encore, bandeau rouge), puis il se BLOQUE.
--   - Le blocage est verifie aussi cote serveur : meme une appli modifiee
--     ne peut plus rien enregistrer tant que ce n'est pas paye.
--   - Tu peux a tout moment suspendre/reactiver, prolonger, offrir des jours.
-- =====================================================================

-- ---------- Champs d'abonnement sur le club ----------
alter table public.clubs add column if not exists monthly_price integer not null default 25000
  check (monthly_price >= 0);
alter table public.clubs add column if not exists expires_at timestamptz;      -- null = illimite
alter table public.clubs add column if not exists suspended boolean not null default false;  -- blocage manuel

-- Delai de grace avant blocage (7 jours).
create or replace function public.yds_grace() returns interval
language sql immutable as $$ select interval '7 days' $$;

-- ---------- Administrateurs de la plateforme (toi) ----------
create table if not exists public.platform_admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.platform_admins enable row level security;  -- aucune regle : personne ne la lit directement

create or replace function public.is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid())
$$;

create or replace function public._exiger_admin() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Reserve a l''administrateur de YDS Night';
  end if;
end $$;

-- ---------- Paiements d'abonnement recus ----------
create table if not exists public.subscription_payments (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  amount      integer not null check (amount > 0),
  months      integer not null check (months between 0 and 36),
  method      text not null check (method in ('mobile_money', 'cash', 'bank', 'other')),
  note        text,
  period_end  timestamptz not null,   -- nouvelle fin d'abonnement apres ce paiement
  recorded_by uuid references auth.users(id) default auth.uid(),
  paid_at     timestamptz not null default now()
);
create index if not exists subscription_payments_club_idx on public.subscription_payments (club_id, paid_at);
alter table public.subscription_payments enable row level security;
drop policy if exists subscription_payments_read on public.subscription_payments;
create policy subscription_payments_read on public.subscription_payments for select
  using (club_id = public.my_club() and public.is_patron());

-- ---------- Etat de l'abonnement d'un club ----------
-- 'actif' | 'bientot' (actif, mais <= 7 jours avant la fin) | 'grace' | 'bloque'
create or replace function public._club_etat(c public.clubs) returns text
language sql stable as $$
  select case
    when c.suspended then 'bloque'
    when c.expires_at is null then 'actif'
    when now() < c.expires_at - public.yds_grace() then 'actif'
    when now() < c.expires_at then 'bientot'
    when now() < c.expires_at + public.yds_grace() then 'grace'
    else 'bloque'
  end
$$;

-- Lu par l'application a chaque ouverture (n'importe quel membre de son club).
create or replace function public.subscription_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c public.clubs; v_etat text;
begin
  if public.is_platform_admin() then
    return jsonb_build_object('etat', 'actif', 'admin', true, 'bloquant', false);
  end if;
  select * into c from public.clubs where id = public.my_club();
  if not found then return jsonb_build_object('etat', 'sans_club', 'bloquant', true); end if;
  v_etat := public._club_etat(c);
  return jsonb_build_object(
    'etat', v_etat,
    'bloquant', v_etat = 'bloque',
    'patron', public.is_patron(),
    'club', c.name,
    'expire_le', c.expires_at,
    'grace_jours', extract(day from public.yds_grace())::int);
end $$;

-- Refuse d'agir quand l'abonnement est bloque (verif cote serveur).
create or replace function public._check_active() returns void
language plpgsql stable security definer set search_path = public as $$
declare c public.clubs;
begin
  if public.is_platform_admin() then return; end if;
  select * into c from public.clubs where id = public.my_club();
  if not found then raise exception 'ABONNEMENT: aucun club'; end if;
  if public._club_etat(c) = 'bloque' then
    raise exception 'ABONNEMENT_EXPIRE: abonnement termine, contactez YDS Night';
  end if;
end $$;

-- On renforce les gardes de base : plus aucune action quand c'est bloque.
create or replace function public._require_member()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v uuid := public.my_member_id();
begin
  if v is null then raise exception 'Compte non autorise'; end if;
  perform public._check_active();
  return v;
end $$;

create or replace function public._require_staff()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v uuid := public._require_member();
begin
  if not public.is_staff() then raise exception 'Reserve au patron et au gerant'; end if;
  return v;
end $$;

-- ---------- Valeurs de depart d'un nouveau club ----------
create or replace function public._seed_club_defaults(p_club uuid, p_name text) returns void
language plpgsql security definer set search_path = public as $$
declare v_cat jsonb; v_cat_id uuid; v_ord int := 0; v_t text; v_torder int := 0;
begin
  -- Reglages
  insert into public.settings (club_id, club_name, ticket_header)
  values (p_club, p_name, upper(p_name))
  on conflict (club_id) do nothing;

  -- Categories de menu (vides : le patron ajoute ses boissons et prix)
  for v_t in select unnest(array[
      'Whiskies et liqueurs', 'Champagnes', 'Vins', 'Bieres',
      'Sodas et jus', 'Cocktails', 'Eau', 'Autres'])
  loop
    v_ord := v_ord + 1;
    insert into public.categories (club_id, name, sort_order)
    values (p_club, v_t, case when v_t = 'Autres' then 99 else v_ord end)
    on conflict (club_id, name) do nothing;
  end loop;

  -- Quelques tables de depart
  for v_t in select unnest(array['VIP 1', 'VIP 2', 'Table 1', 'Table 2', 'Table 3', 'Table 4', 'Comptoir'])
  loop
    v_torder := v_torder + 1;
    insert into public.club_tables (club_id, name, zone, is_fixed, sort_order)
    values (p_club, v_t,
            case when v_t like 'VIP%' then 'vip' when v_t = 'Comptoir' then 'comptoir' else 'salle' end,
            true, v_torder)
    on conflict (club_id, name) do nothing;
  end loop;
end $$;

-- =====================================================================
-- Espace admin (toi)
-- =====================================================================

-- Creer un club + son patron, et fixer la date de fin d'abonnement.
-- Renvoie le code du club (a donner au client) et l'identifiant du patron.
create or replace function public.admin_create_club(
  p_club_name text,
  p_patron_login text,
  p_patron_pin text,
  p_patron_name text,
  p_phone text default null,
  p_months integer default 1,
  p_monthly_price integer default 25000
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_club uuid; v_code text; v_uid uuid; v_fin timestamptz;
begin
  perform public._exiger_admin();
  if coalesce(trim(p_club_name), '') = '' then raise exception 'Donnez un nom au club'; end if;
  perform public._check_login_pin(p_patron_login, p_patron_pin);
  if coalesce(trim(p_patron_name), '') = '' then raise exception 'Indiquez le nom du patron'; end if;
  if coalesce(p_months, 0) < 0 or p_months > 120 then raise exception 'Nombre de mois invalide'; end if;

  v_fin := case when coalesce(p_months, 0) > 0 then now() + make_interval(months => p_months) end;

  -- Code unique du club
  loop
    v_code := public._club_nouveau_code();
    exit when not exists (select 1 from public.clubs where code = v_code);
  end loop;

  insert into public.clubs (name, phone, code, monthly_price, expires_at)
  values (trim(p_club_name), p_phone, v_code, coalesce(p_monthly_price, 25000), v_fin)
  returning id into v_club;

  -- Le patron
  v_uid := public._create_auth_user(p_patron_login, p_patron_pin, v_code);
  update public.clubs set owner_user_id = v_uid where id = v_club;
  insert into public.members (club_id, user_id, login, role, display_name, phone)
  values (v_club, v_uid, lower(trim(p_patron_login)), 'patron', trim(p_patron_name), p_phone);

  perform public._seed_club_defaults(v_club, trim(p_club_name));

  return jsonb_build_object(
    'club_id', v_club, 'code', v_code,
    'patron_login', lower(trim(p_patron_login)),
    'expire_le', v_fin, 'mensuel', coalesce(p_monthly_price, 25000));
end $$;

-- Chiffres globaux
create or replace function public.admin_overview() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  return (select jsonb_build_object(
    'clubs',        (select count(*) from public.clubs),
    'actifs',       (select count(*) from public.clubs c where public._club_etat(c) in ('actif','bientot')),
    'en_grace',     (select count(*) from public.clubs c where public._club_etat(c) = 'grace'),
    'bloques',      (select count(*) from public.clubs c where public._club_etat(c) = 'bloque'),
    'revenu_mensuel', (select coalesce(sum(monthly_price), 0) from public.clubs c
                        where public._club_etat(c) in ('actif','bientot','grace')),
    'encaisse_mois', (select coalesce(sum(amount), 0) from public.subscription_payments
                       where paid_at >= date_trunc('month', now())),
    'fin_proche',   (select count(*) from public.clubs c where public._club_etat(c) = 'bientot')
  ));
end $$;

-- Liste des clubs
create or replace function public.admin_clubs() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  return coalesce((
    select jsonb_agg(x order by x->>'expire_le' nulls last) from (
      select jsonb_build_object(
        'id', c.id,
        'nom', c.name,
        'code', c.code,
        'cree_le', c.created_at,
        'etat', public._club_etat(c),
        'expire_le', c.expires_at,
        'mensuel', c.monthly_price,
        'suspendu', c.suspended,
        'patron', (select m.display_name from public.members m
                    where m.club_id = c.id and m.role = 'patron' limit 1),
        'telephone', c.phone,
        'derniere_soiree', (select max(n.opened_at) from public.nights n where n.club_id = c.id)
      ) as x
      from public.clubs c
    ) t
  ), '[]'::jsonb);
end $$;

-- Fiche d'un club (avec ses paiements)
create or replace function public.admin_club_detail(p_club_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  return (select jsonb_build_object(
    'id', c.id, 'nom', c.name, 'code', c.code, 'cree_le', c.created_at,
    'etat', public._club_etat(c), 'expire_le', c.expires_at,
    'mensuel', c.monthly_price, 'suspendu', c.suspended, 'telephone', c.phone,
    'patron', (select m.display_name from public.members m where m.club_id = c.id and m.role = 'patron' limit 1),
    'equipe', (select count(*) from public.members m where m.club_id = c.id and m.active),
    'paiements', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'montant', p.amount, 'mois', p.months, 'moyen', p.method,
        'note', p.note, 'le', p.paid_at, 'jusqu_au', p.period_end
      ) order by p.paid_at desc), '[]'::jsonb)
      from public.subscription_payments p where p.club_id = c.id)
  ) from public.clubs c where c.id = p_club_id);
end $$;

-- Paiement recu : prolonge l'abonnement de N mois (a la suite s'il reste de la grace, sinon depuis aujourd'hui).
create or replace function public.admin_record_payment(
  p_club_id uuid, p_amount integer, p_months integer, p_method text, p_note text default null
) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare c public.clubs; v_debut timestamptz; v_fin timestamptz;
begin
  perform public._exiger_admin();
  if coalesce(p_amount, 0) <= 0 then raise exception 'Indiquez le montant recu'; end if;
  if coalesce(p_months, 0) not between 1 and 36 then raise exception 'Nombre de mois invalide'; end if;
  select * into c from public.clubs where id = p_club_id for update;
  if not found then raise exception 'Club introuvable'; end if;

  v_debut := case when c.expires_at is null or c.expires_at < now() - public.yds_grace()
                  then now() else c.expires_at end;
  v_fin := v_debut + make_interval(months => p_months);
  update public.clubs set expires_at = v_fin, suspended = false where id = p_club_id;
  insert into public.subscription_payments (club_id, amount, months, method, note, period_end)
  values (p_club_id, p_amount, p_months, p_method, nullif(trim(p_note), ''), v_fin);
  return v_fin;
end $$;

-- Offrir des jours (prolonger, geste commercial)
create or replace function public.admin_extend(p_club_id uuid, p_days integer) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare c public.clubs; v_fin timestamptz;
begin
  perform public._exiger_admin();
  if coalesce(p_days, 0) not between 1 and 365 then raise exception 'Nombre de jours invalide'; end if;
  select * into c from public.clubs where id = p_club_id for update;
  if not found then raise exception 'Club introuvable'; end if;
  v_fin := greatest(coalesce(c.expires_at, now()), now()) + make_interval(days => p_days);
  update public.clubs set expires_at = v_fin where id = p_club_id;
  return v_fin;
end $$;

-- Date de fin precise (null = illimite)
create or replace function public.admin_set_expiry(p_club_id uuid, p_expires_at timestamptz) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  update public.clubs set expires_at = p_expires_at where id = p_club_id;
  if not found then raise exception 'Club introuvable'; end if;
end $$;

-- Suspendre / reactiver a la main (blocage immediat)
create or replace function public.admin_set_suspended(p_club_id uuid, p_suspendre boolean) returns text
language plpgsql security definer set search_path = public as $$
declare c public.clubs;
begin
  perform public._exiger_admin();
  update public.clubs set suspended = coalesce(p_suspendre, false) where id = p_club_id
  returning * into c;
  if not found then raise exception 'Club introuvable'; end if;
  return public._club_etat(c);
end $$;

-- Prix mensuel personnalise (remise negociee)
create or replace function public.admin_set_price(p_club_id uuid, p_price integer) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  if coalesce(p_price, -1) < 0 then raise exception 'Prix invalide'; end if;
  update public.clubs set monthly_price = p_price where id = p_club_id;
end $$;

-- Reinitialiser le PIN du patron d'un club (patron qui a oublie son code)
create or replace function public.admin_reset_patron_pin(p_club_id uuid, p_pin text) returns void
language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_uid uuid;
begin
  perform public._exiger_admin();
  if coalesce(p_pin, '') !~ '^[0-9]{6}$' then raise exception 'Le code PIN doit contenir exactement 6 chiffres'; end if;
  select user_id into v_uid from public.members
   where club_id = p_club_id and role = 'patron' and active
   order by created_at limit 1;
  if v_uid is null then raise exception 'Patron introuvable'; end if;
  update auth.users set encrypted_password = extensions.crypt(p_pin, extensions.gen_salt('bf')),
                        updated_at = now()
   where id = v_uid;
end $$;

-- Supprimer un club de test (efface toutes ses donnees)
create or replace function public.admin_delete_club(p_club_id uuid) returns void
language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid;
begin
  perform public._exiger_admin();
  for v_uid in select user_id from public.members where club_id = p_club_id and user_id is not null loop
    delete from auth.users where id = v_uid;
  end loop;
  delete from public.clubs where id = p_club_id;   -- cascade sur toutes les tables du club
end $$;

-- ---------- Droits d'execution ----------
revoke execute on function public.yds_grace(), public._club_etat(public.clubs),
  public._check_active(), public._seed_club_defaults(uuid, text)
  from public, anon, authenticated;

revoke execute on function public.is_platform_admin(), public.subscription_status(),
  public.admin_create_club(text, text, text, text, text, integer, integer),
  public.admin_overview(), public.admin_clubs(), public.admin_club_detail(uuid),
  public.admin_record_payment(uuid, integer, integer, text, text),
  public.admin_extend(uuid, integer), public.admin_set_expiry(uuid, timestamptz),
  public.admin_set_suspended(uuid, boolean), public.admin_set_price(uuid, integer),
  public.admin_reset_patron_pin(uuid, text), public.admin_delete_club(uuid)
  from public, anon;
grant execute on function public.is_platform_admin(), public.subscription_status(),
  public.admin_create_club(text, text, text, text, text, integer, integer),
  public.admin_overview(), public.admin_clubs(), public.admin_club_detail(uuid),
  public.admin_record_payment(uuid, integer, integer, text, text),
  public.admin_extend(uuid, integer), public.admin_set_expiry(uuid, timestamptz),
  public.admin_set_suspended(uuid, boolean), public.admin_set_price(uuid, integer),
  public.admin_reset_patron_pin(uuid, text), public.admin_delete_club(uuid)
  to authenticated;

notify pgrst, 'reload schema';
