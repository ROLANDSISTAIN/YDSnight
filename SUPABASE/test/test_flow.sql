-- Test fonctionnel YDS Night : flux complet + isolation + blocage abonnement
\set ON_ERROR_STOP on
set client_min_messages = warning;

-- Admin de la plateforme
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000aa', 'admin@yds.test');
insert into public.platform_admins (user_id) values ('00000000-0000-0000-0000-0000000000aa');

do $$
declare
  r_a jsonb; r_b jsonb;
  club_a uuid; club_b uuid; code_a text;
  pat_a uuid; pat_b uuid; ger_a uuid; serv_a uuid;
  ger_a_uid uuid; serv_a_uid uuid;
  table_a uuid; prod_a uuid; tab uuid; it1 uuid; it2 uuid;
  v jsonb; v_ticket bigint; v_total int;
begin
  -- ===== Admin cree deux clubs =====
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000aa', false);
  r_a := public.admin_create_club('Club A', 'patrona', '111111', 'Pat A', '90000000', 1, 25000);
  r_b := public.admin_create_club('Club B', 'patronb', '222222', 'Pat B', '91000000', 1, 25000);
  club_a := (r_a->>'club_id')::uuid;  code_a := r_a->>'code';
  club_b := (r_b->>'club_id')::uuid;
  raise notice 'Club A cree, code=%, Club B cree, code=%', code_a, (r_b->>'code');

  select user_id into pat_a from public.members where club_id = club_a and role = 'patron';
  select user_id into pat_b from public.members where club_id = club_b and role = 'patron';

  -- ===== Patron A cree son equipe =====
  perform set_config('request.jwt.claim.sub', pat_a::text, false);
  if public.my_club() <> club_a then raise exception 'ECHEC: my_club du patron A faux'; end if;
  ger_a  := public.create_member('gerant1', '333333', 'Gerant A', 'gerant');
  serv_a := public.create_member('serveuse1', '444444', 'Serveuse A', 'serveuse');
  select user_id into ger_a_uid  from public.members where id = ger_a;
  select user_id into serv_a_uid from public.members where id = serv_a;
  raise notice 'Equipe A creee (gerant + serveuse)';

  -- Le patron ajoute une boisson (ecriture directe, comme l'app sous RLS)
  insert into public.products (club_id, name, sale_price, purchase_price, track_stock)
  values (club_a, 'Biere XYZ', 2000, 1200, true) returning id into prod_a;
  -- Stock de depart
  perform set_config('request.jwt.claim.sub', ger_a_uid::text, false);
  perform public.receive_stock(prod_a, 100, 1200);

  -- ===== Soiree : gerant ouvre =====
  perform public.open_night(10000);
  select id into table_a from public.club_tables where club_id = club_a limit 1;

  -- ===== Serveuse : ouvre une table, ajoute 2 bieres =====
  perform set_config('request.jwt.claim.sub', serv_a_uid::text, false);
  if public.my_club() <> club_a then raise exception 'ECHEC: my_club serveuse A faux'; end if;
  tab := public.open_tab(table_a);
  perform public.add_items(tab, jsonb_build_array(jsonb_build_object('product_id', prod_a, 'quantity', 2)));
  select id into it1 from public.tab_items where tab_id = tab limit 1;

  -- ===== Gerant : sert la boisson (stock baisse) =====
  perform set_config('request.jwt.claim.sub', ger_a_uid::text, false);
  perform public.serve_items(array[it1]);

  -- ===== Serveuse : demande l'encaissement =====
  perform set_config('request.jwt.claim.sub', serv_a_uid::text, false);
  v_total := public.request_payment(tab);
  raise notice 'Total note = % FCFA (attendu 4000)', v_total;
  if v_total <> 4000 then raise exception 'ECHEC: total attendu 4000, obtenu %', v_total; end if;

  -- ===== Gerant : encaisse =====
  perform set_config('request.jwt.claim.sub', ger_a_uid::text, false);
  v := public.record_payment(tab, 'cash', 4000);
  v_ticket := (v->>'ticket_number')::bigint;
  raise notice 'Encaissement: statut=%, ticket=% (attendu 1)', v->>'status', v_ticket;
  if v->>'status' <> 'paid' or v_ticket <> 1 then raise exception 'ECHEC: encaissement %', v; end if;

  -- Stock restant = 100 - 2 = 98
  if (select quantity from public.product_stock where product_id = prod_a) <> 98 then
    raise exception 'ECHEC: stock attendu 98';
  end if;
  raise notice 'Stock restant OK (98)';

  -- ===== ISOLATION : patron B ne voit rien de A =====
  perform set_config('request.jwt.claim.sub', pat_b::text, false);
  if public.my_club() <> club_b then raise exception 'ECHEC: my_club patron B faux'; end if;
  -- Ouvrir une table de A depuis B doit echouer
  perform public.open_night(0);
  begin
    perform public.open_tab(table_a);
    raise exception 'ECHEC ISOLATION: B a pu ouvrir une table de A';
  exception when others then
    if sqlerrm like 'ECHEC%' then raise; end if;
    raise notice 'Isolation OK: B ne peut pas toucher la table de A (%)', sqlerrm;
  end;
  -- night_report de B ne doit montrer aucun revenu de A
  v := public.night_report();
  if (v->>'revenue')::int <> 0 then raise exception 'ECHEC ISOLATION: B voit du revenu'; end if;
  raise notice 'Isolation rapports OK (B revenu = 0)';

  -- ===== BLOCAGE ABONNEMENT : A expire depuis 10 jours (> 7j de grace) =====
  update public.clubs set expires_at = now() - interval '10 days' where id = club_a;
  perform set_config('request.jwt.claim.sub', ger_a_uid::text, false);
  v := public.subscription_status();
  raise notice 'Abonnement A: etat=%, bloquant=%', v->>'etat', v->>'bloquant';
  if (v->>'bloquant')::boolean is not true then raise exception 'ECHEC: A devrait etre bloque'; end if;
  begin
    perform public.open_night(0);
    raise exception 'ECHEC BLOCAGE: A a pu agir malgre abonnement expire';
  exception when others then
    if sqlerrm like 'ECHEC%' then raise; end if;
    raise notice 'Blocage serveur OK: action refusee (%)', sqlerrm;
  end;

  -- ===== GRACE : A expire depuis 3 jours (dans les 7j) : marche encore =====
  update public.clubs set expires_at = now() - interval '3 days' where id = club_a;
  v := public.subscription_status();
  raise notice 'Abonnement A (grace): etat=%, bloquant=%', v->>'etat', v->>'bloquant';
  if v->>'etat' <> 'grace' or (v->>'bloquant')::boolean then raise exception 'ECHEC: A devrait etre en grace'; end if;

  -- ===== Paiement admin reactive =====
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000aa', false);
  perform public.admin_record_payment(club_a, 25000, 1, 'mobile_money', 'test');
  perform set_config('request.jwt.claim.sub', ger_a_uid::text, false);
  v := public.subscription_status();
  raise notice 'Apres paiement: etat=%, bloquant=%', v->>'etat', v->>'bloquant';
  if (v->>'bloquant')::boolean then raise exception 'ECHEC: A devrait etre reactive'; end if;

  raise notice '================= TOUS LES TESTS PASSENT =================';
end $$;
