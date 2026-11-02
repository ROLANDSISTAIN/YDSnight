-- =====================================================================
-- YDS NIGHT · Script 01 · Les tables
-- A coller en entier dans Supabase > SQL Editor > New query, puis "Run".
-- Montants en FCFA (nombres entiers).
--
-- Difference avec Harem Club : YDS Night est multi-clients.
-- Chaque boite de nuit est un "club" isole. La colonne club_id, presente
-- sur chaque table, dit a quel club appartient la ligne. Un club ne voit
-- jamais les donnees d'un autre (voir script 02).
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- Les clubs (les clients de YDS Night). Un client = un club.
-- Le patron qui cree le compte en est le proprietaire (owner_user_id).
-- ---------------------------------------------------------------------
create table if not exists public.clubs (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  owner_user_id  uuid references auth.users(id),
  phone          text,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Reglages du club (une seule ligne par club)
-- ---------------------------------------------------------------------
create table if not exists public.settings (
  club_id          uuid primary key references public.clubs(id) on delete cascade,
  club_name        text not null default 'Ma boite de nuit',
  phone            text,
  ticket_header    text not null default 'MA BOITE',
  ticket_footer    text not null default 'Merci de votre visite',
  night_start_hour int  not null default 18 check (night_start_hour between 0 and 23),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- L'equipe : patron, gerant (caissier), serveuses
-- L'identifiant (login) est unique a l'interieur d'un club.
-- ---------------------------------------------------------------------
create table if not exists public.members (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.clubs(id) on delete cascade,
  user_id       uuid unique references auth.users(id) on delete set null,
  login         text not null check (login ~ '^[a-z0-9._-]{3,30}$'),
  role          text not null check (role in ('patron', 'gerant', 'serveuse')),
  display_name  text not null,
  phone         text,
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (club_id, login)
);
create index if not exists members_club_idx on public.members (club_id);

-- ---------------------------------------------------------------------
-- Les tables du club
-- ---------------------------------------------------------------------
create table if not exists public.club_tables (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  name        text not null,
  zone        text not null default 'salle' check (zone in ('salle', 'vip', 'comptoir', 'terrasse')),
  is_fixed    boolean not null default true,
  active      boolean not null default true,
  sort_order  int not null default 0,
  created_by  uuid references public.members(id),
  created_at  timestamptz not null default now(),
  unique (club_id, name)
);

-- ---------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  name        text not null,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  unique (club_id, name)
);

create table if not exists public.products (
  id              uuid primary key default gen_random_uuid(),
  club_id         uuid not null references public.clubs(id) on delete cascade,
  category_id     uuid references public.categories(id),
  name            text not null,
  sale_price      int  not null check (sale_price >= 0),
  purchase_price  int  not null default 0 check (purchase_price >= 0),
  track_stock     boolean not null default true,   -- non pour les cocktails
  min_stock       int  not null default 0 check (min_stock >= 0),
  active          boolean not null default true,
  sort_order      int  not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (club_id, category_id, name)
);
create index if not exists products_club_idx on public.products (club_id);

create table if not exists public.suppliers (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  name        text not null,
  phone       text,
  note        text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Soirees, notes, boissons, paiements
-- ---------------------------------------------------------------------
create table if not exists public.nights (
  id               uuid primary key default gen_random_uuid(),
  club_id          uuid not null references public.clubs(id) on delete cascade,
  status           text not null default 'open' check (status in ('open', 'closed')),
  opened_by        uuid references public.members(id),
  opened_at        timestamptz not null default now(),
  opening_float    int not null default 0 check (opening_float >= 0),
  closed_by        uuid references public.members(id),
  closed_at        timestamptz,
  expected_cash    int,
  expected_momo    int,
  counted_cash     int,
  counted_momo     int,
  difference_cash  int,
  difference_momo  int,
  note             text
);
-- une seule soiree ouverte a la fois, PAR CLUB
create unique index if not exists nights_one_open on public.nights (club_id) where status = 'open';
create index if not exists nights_club_idx on public.nights (club_id);

create table if not exists public.tabs (
  id             uuid primary key default gen_random_uuid(),
  club_id        uuid not null references public.clubs(id) on delete cascade,
  night_id       uuid not null references public.nights(id),
  table_id       uuid not null references public.club_tables(id),
  waitress_id    uuid not null references public.members(id),
  status         text not null default 'open' check (status in ('open', 'to_pay', 'paid', 'cancelled')),
  ticket_number  bigint,
  total          int not null default 0,
  paid_amount    int not null default 0,
  opened_at      timestamptz not null default now(),
  requested_at   timestamptz,
  paid_at        timestamptz,
  cashier_id     uuid references public.members(id),
  cancelled_by   uuid references public.members(id),
  cancel_reason  text,
  unique (club_id, ticket_number)
);
-- une seule note en cours par table
create unique index if not exists tabs_one_active_per_table
  on public.tabs (table_id) where status in ('open', 'to_pay');
create index if not exists tabs_night_idx on public.tabs (night_id);
create index if not exists tabs_waitress_idx on public.tabs (waitress_id);
create index if not exists tabs_club_idx on public.tabs (club_id);

create table if not exists public.tab_items (
  id              uuid primary key default gen_random_uuid(),
  club_id         uuid not null references public.clubs(id) on delete cascade,
  tab_id          uuid not null references public.tabs(id) on delete cascade,
  product_id      uuid not null references public.products(id),
  product_name    text not null,                 -- nom fige au moment de la commande
  quantity        int  not null check (quantity > 0),
  unit_price      int  not null check (unit_price >= 0),  -- prix fige
  cost_price      int  not null default 0,               -- cout fige (cache aux serveuses)
  status          text not null default 'requested'
                  check (status in ('requested', 'served', 'refused', 'removed')),
  requested_at    timestamptz not null default now(),
  requested_by    uuid references public.members(id),
  served_by       uuid references public.members(id),
  served_at       timestamptz,
  removed_by      uuid references public.members(id),
  removed_at      timestamptz,
  removed_reason  text
);
create index if not exists tab_items_tab_idx on public.tab_items (tab_id);
create index if not exists tab_items_club_idx on public.tab_items (club_id);

create table if not exists public.payments (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  tab_id       uuid not null references public.tabs(id),
  night_id     uuid not null references public.nights(id),
  method       text not null check (method in ('cash', 'mobile_money')),
  amount       int  not null check (amount > 0),
  received_by  uuid references public.members(id),
  created_at   timestamptz not null default now()
);
create index if not exists payments_tab_idx on public.payments (tab_id);
create index if not exists payments_club_idx on public.payments (club_id);

-- ---------------------------------------------------------------------
-- Caisse et depenses
-- ---------------------------------------------------------------------
create table if not exists public.cash_movements (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  night_id    uuid not null references public.nights(id),
  type        text not null check (type in ('in', 'out')),
  amount      int  not null check (amount > 0),
  reason      text not null,
  member_id   uuid references public.members(id),
  created_at  timestamptz not null default now()
);

create table if not exists public.expenses (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  night_id     uuid references public.nights(id),
  label        text not null,
  category     text,
  amount       int  not null check (amount > 0),
  method       text not null default 'cash' check (method in ('cash', 'mobile_money')),
  from_till    boolean not null default true,   -- paye avec l'argent de la caisse
  supplier_id  uuid references public.suppliers(id),
  member_id    uuid references public.members(id),
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Stock
-- ---------------------------------------------------------------------
create table if not exists public.inventories (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.clubs(id) on delete cascade,
  nb_products   int not null default 0,
  nb_ecarts     int not null default 0,
  ecart_valeur  int not null default 0,
  note          text,
  member_id     uuid references public.members(id),
  created_at    timestamptz not null default now()
);

create table if not exists public.stock_entries (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  product_id   uuid not null references public.products(id),
  quantity     int  not null check (quantity > 0),
  cost_price   int  not null default 0 check (cost_price >= 0),
  supplier_id  uuid references public.suppliers(id),
  note         text,
  member_id    uuid references public.members(id),
  created_at   timestamptz not null default now()
);

create table if not exists public.stock_movements (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.clubs(id) on delete cascade,
  product_id    uuid not null references public.products(id),
  type          text not null check (type in ('purchase', 'served', 'return', 'loss', 'adjustment', 'inventory')),
  quantity      int  not null,    -- positif = entree, negatif = sortie
  tab_item_id   uuid references public.tab_items(id),
  entry_id      uuid references public.stock_entries(id),
  inventory_id  uuid references public.inventories(id),
  reason        text,
  member_id     uuid references public.members(id),
  created_at    timestamptz not null default now()
);
create index if not exists stock_movements_product_idx on public.stock_movements (product_id);
create index if not exists stock_movements_club_idx on public.stock_movements (club_id);

-- Stock actuel par boisson (reste limite au club par les droits : security_invoker)
create or replace view public.product_stock
with (security_invoker = true) as
select p.id as product_id,
       p.club_id as club_id,
       coalesce(sum(m.quantity), 0)::int as quantity
from public.products p
left join public.stock_movements m on m.product_id = p.id
where p.track_stock
group by p.id, p.club_id;

-- ---------------------------------------------------------------------
-- Mise a jour automatique de updated_at
-- ---------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists products_touch on public.products;
create trigger products_touch before update on public.products
  for each row execute function public.touch_updated_at();

drop trigger if exists settings_touch on public.settings;
create trigger settings_touch before update on public.settings
  for each row execute function public.touch_updated_at();
