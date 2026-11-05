-- =====================================================================
-- 11_menu_boissons.sql  —  Menu de base des boissons (YDS Night)
-- ---------------------------------------------------------------------
-- Charge un menu complet (categories + boissons + prix en FCFA) dans un
-- club. Les cocktails ne suivent pas le stock (faits a la demande).
--
--  * _seed_club_menu(club)       : charge le menu dans un club.
--  * admin_seed_menu(club)       : meme chose, depuis l'espace admin.
--  * Appel automatique a la creation d'un club (voir 08, _seed_club_defaults).
--  * En fin de fichier : chargement immediat dans les clubs deja crees.
--
-- Re-executable sans risque : « on conflict do nothing » n'ecrase jamais
-- un prix deja modifie par le patron.
-- =====================================================================

create or replace function public._seed_club_menu(p_club uuid) returns int
language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  -- Les categories (creees si elles manquent). « Autres » reste en dernier.
  insert into public.categories (club_id, name, sort_order) values
    (p_club, 'Whiskies et liqueurs', 1),
    (p_club, 'Champagnes',           2),
    (p_club, 'Vins',                 3),
    (p_club, 'Bieres',               4),
    (p_club, 'Sodas et jus',         5),
    (p_club, 'Cocktails',            6),
    (p_club, 'Eau',                  7),
    (p_club, 'Autres',              99)
  on conflict (club_id, name) do nothing;

  -- cat = categorie, nom = boisson, prix = prix de vente (FCFA),
  -- stock = suivre le stock ? (non pour les cocktails et le cafe), ord = ordre.
  with m(cat, nom, prix, stock, ord) as (values
    -- WHISKIES
    ('Whiskies et liqueurs', 'HIGHLAND PARK 12',            105000, true,  1),
    ('Whiskies et liqueurs', 'MACALLAN 12',                 110000, true,  2),
    ('Whiskies et liqueurs', 'GLENFIDDICH 12',               60000, true,  3),
    ('Whiskies et liqueurs', 'HENNESSY',                     60000, true,  4),
    ('Whiskies et liqueurs', 'DOUBLE BLACK 75cl',            60000, true,  5),
    ('Whiskies et liqueurs', 'GLENFIDDICH 15',               70000, true,  6),
    ('Whiskies et liqueurs', 'GRAND MARNIER',                70000, true,  7),
    ('Whiskies et liqueurs', 'AMARETTO',                     70000, true,  8),
    ('Whiskies et liqueurs', 'DOUBLE BLACK 1L',              65000, true,  9),
    ('Whiskies et liqueurs', 'REMY MARTIN',                  65000, true, 10),
    ('Whiskies et liqueurs', 'DON JULIO',                    75000, true, 11),
    ('Whiskies et liqueurs', 'BLACK LABEL',                  50000, true, 12),
    ('Whiskies et liqueurs', 'CHIVAS',                       50000, true, 13),
    ('Whiskies et liqueurs', 'DIMPLE',                       50000, true, 14),
    ('Whiskies et liqueurs', 'RED LABEL',                    40000, true, 15),
    ('Whiskies et liqueurs', 'JACK DANIEL''S',               40000, true, 16),
    ('Whiskies et liqueurs', 'BAILEYS',                      40000, true, 17),
    ('Whiskies et liqueurs', 'COGNAC VSOP XQ BOURGEOISIE',   50000, true, 18),
    ('Whiskies et liqueurs', 'GRANT''S',                     25000, true, 19),
    -- EAUX DE VIE (spiritueux)
    ('Whiskies et liqueurs', 'GORDON''S GIN',                30000, true, 20),
    ('Whiskies et liqueurs', 'BEEFEATER',                    30000, true, 21),
    ('Whiskies et liqueurs', 'ABSOLUT',                      25000, true, 22),
    ('Whiskies et liqueurs', 'RHUM ST JAMES',                25000, true, 23),
    ('Whiskies et liqueurs', 'RHUM BACARDI',                 25000, true, 24),
    ('Whiskies et liqueurs', 'COINTREAU',                    40000, true, 25),
    ('Whiskies et liqueurs', 'VODKA',                        20000, true, 26),
    ('Whiskies et liqueurs', 'VODKA BELVEDERE',              65000, true, 27),
    ('Whiskies et liqueurs', 'VODKA GREY GOOSE',             55000, true, 28),
    -- CHAMPAGNES
    ('Champagnes', 'LAURENT PERRIER',                        50000, true,  1),
    ('Champagnes', 'DUCHESSE',                               50000, true,  2),
    ('Champagnes', 'MOET CHANDON GOBILLARD & FILS',          60000, true,  3),
    ('Champagnes', 'MOET BRUT',                              65000, true,  4),
    ('Champagnes', 'RUINART BRUT',                           95000, true,  5),
    ('Champagnes', 'RUINART BLANC',                         145000, true,  6),
    ('Champagnes', 'VEUVE CLICQUOT',                         70000, true,  7),
    ('Champagnes', 'BELAIRE',                                45000, true,  8),
    -- VINS
    ('Vins', 'VIN I',                                        12000, true,  1),
    ('Vins', 'VIN II',                                       15000, true,  2),
    ('Vins', 'VIN MOUSSEUX I',                               15000, true,  3),
    ('Vins', 'VIN MOUSSEUX II',                              20000, true,  4),
    -- BIERES
    ('Bieres', 'PILS',                                        2000, true,  1),
    ('Bieres', 'DJAMA',                                       2000, true,  2),
    ('Bieres', 'BEAUFORT',                                    2000, true,  3),
    ('Bieres', 'GUINNESS',                                    2500, true,  4),
    ('Bieres', 'DESPERADOS',                                  2500, true,  5),
    ('Bieres', 'XXL',                                         2500, true,  6),
    ('Bieres', 'SMIRNOFF ICE',                                2500, true,  7),
    ('Bieres', 'RED''S',                                      2500, true,  8),
    ('Bieres', 'HEINEKEN',                                    2500, true,  9),
    -- SODAS ET JUS
    ('Sodas et jus', 'SODA',                                  1000, true,  1),
    ('Sodas et jus', 'TONIC',                                 1000, true,  2),
    ('Sodas et jus', 'COCA',                                  1000, true,  3),
    ('Sodas et jus', 'SPRITE',                                1000, true,  4),
    -- EAU
    ('Eau', 'EAU 50CL',                                        500, true,  1),
    -- COCKTAILS (sans suivi de stock)
    ('Cocktails', 'COCKTAIL MAISON',                          3500, false, 1),
    ('Cocktails', 'VIRGIN MOJITO',                            3500, false, 2),
    ('Cocktails', 'EXOTIC',                                   3500, false, 3),
    ('Cocktails', 'RED COLADA',                               3500, false, 4),
    ('Cocktails', 'COCKTAIL MAISON ALCOOLISE',               4500, false, 5),
    ('Cocktails', 'MASERATI VODKA',                           4500, false, 6),
    ('Cocktails', 'MOJITO ANANAS',                            4500, false, 7),
    ('Cocktails', 'MOJITO PASSION',                           4500, false, 8),
    ('Cocktails', 'PINA COLADA',                              4500, false, 9),
    -- AUTRES
    ('Autres', 'CAFE',                                        1500, false, 1)
  )
  insert into public.products (club_id, category_id, name, sale_price, track_stock, sort_order)
  select p_club, c.id, m.nom, m.prix, m.stock, m.ord
  from m
  join public.categories c on c.club_id = p_club and c.name = m.cat
  on conflict (club_id, category_id, name) do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end $$;

-- Depuis l'espace admin : (re)charger le menu de base dans un club.
create or replace function public.admin_seed_menu(p_club_id uuid) returns int
language plpgsql security definer set search_path = public as $$
begin
  perform public._exiger_admin();
  return public._seed_club_menu(p_club_id);
end $$;

revoke execute on function public._seed_club_menu(uuid), public.admin_seed_menu(uuid) from public, anon;
grant  execute on function public.admin_seed_menu(uuid) to authenticated;

-- Chargement immediat du menu dans les clubs deja crees.
select public._seed_club_menu(id) from public.clubs;

notify pgrst, 'reload schema';
