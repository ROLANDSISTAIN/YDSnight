-- =====================================================================
-- YDS NIGHT · Script 04 · Les comptes de l'equipe
-- Connexion par CODE DU CLUB + identifiant + code PIN a 6 chiffres.
--
-- Comme YDS Night sert plusieurs clubs, un meme identifiant (ex. "gerant")
-- peut exister dans deux clubs differents. Pour les distinguer, l'adresse
-- interne de Supabase inclut le code du club :
--     identifiant@<code-du-club>.yds-night.invalid
-- Cette adresse ne recoit jamais d'e-mail.
--
-- L'appareil retient le code du club apres la premiere mise en place ;
-- ensuite, l'equipe tape seulement identifiant + PIN.
-- =====================================================================

-- Code court et lisible pour chaque club (sans 0 O 1 I). Sert d'adresse interne.
alter table public.clubs add column if not exists code text unique;

create or replace function public._club_nouveau_code() returns text
language plpgsql volatile as $$
declare
  alphabet constant text := 'abcdefghjkmnpqrstuvwxyz23456789';
  octets bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
  code text := '';
  i int;
begin
  for i in 1..6 loop
    code := code || substr(alphabet, (get_byte(octets, i) % 30) + 1, 1);
  end loop;
  return code;   -- 6 caracteres, ex. "k7m3qp"
end $$;

-- ---------------------------------------------------------------------
-- Outils de connexion
-- ---------------------------------------------------------------------
create or replace function public._login_email(p_login text, p_code text)
returns text language sql immutable as $$
  select lower(trim(p_login)) || '@' || lower(trim(p_code)) || '.yds-night.invalid'
$$;

create or replace function public._check_login_pin(p_login text, p_pin text)
returns void language plpgsql immutable as $$
begin
  if lower(trim(coalesce(p_login, ''))) !~ '^[a-z0-9._-]{3,30}$' then
    raise exception 'Identifiant invalide : 3 a 30 caracteres, lettres minuscules, chiffres, point ou tiret';
  end if;
  if coalesce(p_pin, '') !~ '^[0-9]{6}$' then
    raise exception 'Le code PIN doit contenir exactement 6 chiffres';
  end if;
end $$;

-- Cree l'utilisateur Supabase (auth) pour un club donne et renvoie son identifiant
create or replace function public._create_auth_user(p_login text, p_pin text, p_code text)
returns uuid language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_uid uuid := gen_random_uuid(); v_email text := public._login_email(p_login, p_code);
begin
  if exists (select 1 from auth.users where email = v_email) then
    raise exception 'Cet identifiant est deja utilise dans ce club';
  end if;
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, email_change, email_change_token_new, recovery_token)
  values ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', v_email,
          extensions.crypt(p_pin, extensions.gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now(),
          '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, identity_data, provider,
                               last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_uid, v_uid::text,
          jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
          'email', now(), now(), now());
  return v_uid;
end $$;

-- ---------------------------------------------------------------------
-- Mise en place de l'appareil : retrouver un club par son code.
-- Appelable sans etre connecte (l'appareil confirme le nom du club avant
-- la premiere connexion). Ne renvoie que le nom.
-- ---------------------------------------------------------------------
create or replace function public.club_by_code(p_code text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_club public.clubs;
begin
  select * into v_club from public.clubs where code = lower(trim(p_code));
  if not found then
    return jsonb_build_object('trouve', false);
  end if;
  return jsonb_build_object('trouve', true, 'code', v_club.code, 'nom', v_club.name);
end $$;

-- ---------------------------------------------------------------------
-- Gestion de l'equipe (patron seulement, dans SON club)
-- ---------------------------------------------------------------------
create or replace function public.create_member(p_login text, p_pin text, p_display_name text,
                                                p_role text default 'serveuse', p_phone text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_club uuid := public.my_club(); v_code text; v_uid uuid; v_id uuid;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut creer un compte'; end if;
  if p_role not in ('patron', 'gerant', 'serveuse') then raise exception 'Role inconnu'; end if;
  if coalesce(trim(p_display_name), '') = '' then raise exception 'Indiquez le nom'; end if;
  perform public._check_login_pin(p_login, p_pin);
  select code into v_code from public.clubs where id = v_club;
  if exists (select 1 from public.members where club_id = v_club and login = lower(trim(p_login))) then
    raise exception 'Cet identifiant est deja utilise dans ce club';
  end if;
  v_uid := public._create_auth_user(p_login, p_pin, v_code);
  insert into public.members (club_id, user_id, login, role, display_name, phone)
  values (v_club, v_uid, lower(trim(p_login)), p_role, trim(p_display_name), p_phone)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.set_member_pin(p_member_id uuid, p_pin text)
returns void language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_uid uuid;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut changer un code PIN'; end if;
  if coalesce(p_pin, '') !~ '^[0-9]{6}$' then raise exception 'Le code PIN doit contenir exactement 6 chiffres'; end if;
  select user_id into v_uid from public.members where id = p_member_id and club_id = public.my_club();
  if v_uid is null then raise exception 'Compte introuvable'; end if;
  update auth.users set encrypted_password = extensions.crypt(p_pin, extensions.gen_salt('bf')),
                        updated_at = now()
   where id = v_uid;
end $$;

create or replace function public.update_member(p_member_id uuid, p_display_name text,
                                                p_role text, p_phone text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_club uuid := public.my_club(); v_old public.members;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut modifier un compte'; end if;
  if p_role not in ('patron', 'gerant', 'serveuse') then raise exception 'Role inconnu'; end if;
  select * into v_old from public.members where id = p_member_id and club_id = v_club for update;
  if not found then raise exception 'Compte introuvable'; end if;
  if v_old.role = 'patron' and p_role <> 'patron'
     and (select count(*) from public.members where club_id = v_club and role = 'patron' and active) <= 1 then
    raise exception 'Il doit toujours rester au moins un patron';
  end if;
  update public.members set display_name = trim(p_display_name), role = p_role, phone = p_phone
   where id = p_member_id;
end $$;

-- Desactiver un compte : la personne ne peut plus rien faire, son historique reste
create or replace function public.set_member_active(p_member_id uuid, p_active boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_club uuid := public.my_club(); v_m public.members;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut activer ou desactiver un compte'; end if;
  select * into v_m from public.members where id = p_member_id and club_id = v_club for update;
  if not found then raise exception 'Compte introuvable'; end if;
  if not p_active and v_m.user_id = auth.uid() then
    raise exception 'Vous ne pouvez pas desactiver votre propre compte';
  end if;
  if not p_active and v_m.role = 'patron'
     and (select count(*) from public.members where club_id = v_club and role = 'patron' and active) <= 1 then
    raise exception 'Il doit toujours rester au moins un patron';
  end if;
  update public.members set active = p_active where id = p_member_id;
end $$;

-- ---------------------------------------------------------------------
-- Changer son propre identifiant et code PIN (chacun, depuis Reglages)
-- ---------------------------------------------------------------------
create or replace function public.change_my_credentials(p_new_login text default null, p_new_pin text default null)
returns text language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_me public.members; v_code text; v_login text; v_email text;
begin
  select * into v_me from public.members where user_id = auth.uid() and active;
  if v_me is null then raise exception 'Compte non autorise'; end if;
  select code into v_code from public.clubs where id = v_me.club_id;

  -- Code PIN
  if p_new_pin is not null and p_new_pin <> '' then
    if p_new_pin !~ '^[0-9]{6}$' then
      raise exception 'Le code PIN doit contenir exactement 6 chiffres';
    end if;
    update auth.users
       set encrypted_password = extensions.crypt(p_new_pin, extensions.gen_salt('bf')), updated_at = now()
     where id = v_me.user_id;
  end if;

  -- Identifiant
  v_login := v_me.login;
  if p_new_login is not null and lower(trim(p_new_login)) <> v_me.login then
    v_login := lower(trim(p_new_login));
    if v_login !~ '^[a-z0-9._-]{3,30}$' then
      raise exception 'Identifiant invalide : 3 a 30 caracteres, lettres minuscules, chiffres, point ou tiret';
    end if;
    if exists (select 1 from public.members where club_id = v_me.club_id and login = v_login and id <> v_me.id) then
      raise exception 'Cet identifiant est deja utilise dans ce club';
    end if;
    v_email := public._login_email(v_login, v_code);
    if exists (select 1 from auth.users where email = v_email and id <> v_me.user_id) then
      raise exception 'Cet identifiant est deja utilise dans ce club';
    end if;
    update auth.users set email = v_email, updated_at = now() where id = v_me.user_id;
    update auth.identities
       set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(v_email)), updated_at = now()
     where user_id = v_me.user_id;
    update public.members set login = v_login where id = v_me.id;
  end if;

  return v_login;
end $$;

-- ---------------------------------------------------------------------
-- Supprimer definitivement un membre (patron). Refuse s'il a deja
-- travaille (on le desactive alors pour garder l'historique).
-- ---------------------------------------------------------------------
create or replace function public.delete_member(p_member_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare v_club uuid := public.my_club(); v_m public.members; v_uid uuid;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut supprimer un compte'; end if;
  select * into v_m from public.members where id = p_member_id and club_id = v_club;
  if not found then return; end if;
  if v_m.user_id = auth.uid() then raise exception 'Vous ne pouvez pas supprimer votre propre compte'; end if;
  if v_m.role = 'patron'
     and (select count(*) from public.members where club_id = v_club and role = 'patron' and id <> p_member_id) = 0 then
    raise exception 'Il doit toujours rester au moins un patron';
  end if;

  v_uid := v_m.user_id;
  begin
    delete from public.members where id = p_member_id;
  exception when foreign_key_violation then
    raise exception 'Ce membre a deja travaille (notes, paiements, stock...). '
                    'Impossible de le supprimer sans effacer cet historique : desactivez-le plutot.';
  end;

  if v_uid is not null then
    delete from auth.users where id = v_uid;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Droits d'execution
-- ---------------------------------------------------------------------
revoke execute on function public._club_nouveau_code(), public._login_email(text, text),
  public._check_login_pin(text, text), public._create_auth_user(text, text, text)
  from public, anon, authenticated;

-- club_by_code est appelable sans connexion (mise en place de l'appareil)
revoke execute on function public.club_by_code(text) from public;
grant execute on function public.club_by_code(text) to anon, authenticated;

revoke execute on function public.create_member(text, text, text, text, text),
  public.set_member_pin(uuid, text), public.update_member(uuid, text, text, text),
  public.set_member_active(uuid, boolean), public.change_my_credentials(text, text),
  public.delete_member(uuid)
  from public, anon;
grant execute on function public.create_member(text, text, text, text, text),
  public.set_member_pin(uuid, text), public.update_member(uuid, text, text, text),
  public.set_member_active(uuid, boolean), public.change_my_credentials(text, text),
  public.delete_member(uuid)
  to authenticated;
