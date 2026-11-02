# Base de données YDS Night (Supabase)

YDS Night est la version commerciale, multi-clients, du logiciel de boîte de nuit.
Chaque boîte de nuit est un **club** isolé : un club ne voit jamais les données d'un autre.
L'abonnement (25 000 FCFA/mois, ou à l'année) est porté par le club ; il peut être
bloqué à distance, avec 7 jours de grâce avant la coupure.

Scripts à lancer **dans l'ordre**, une seule fois, dans Supabase > SQL Editor.
Chaque script peut être relancé sans danger s'il y a eu une erreur.

| Script | Contenu |
| --- | --- |
| 01_tables.sql | Toutes les tables (clubs, équipe, tables, menu, soirées, notes, boissons, paiements, caisse, stock). `club_id` sur chaque table. |
| 02_droits.sql | Isolation par club (`my_club()`) + rôles patron / gérant / serveuse. Prix d'achat cachés. |
| 03_fonctions.sql | Soirée, circuit serveuse → bar, encaissement (une ou plusieurs fois), caisse, stock, inventaire, rapports. Numéro de ticket propre à chaque club. |
| 04_comptes.sql | Connexion code du club + identifiant + PIN. Le patron gère son équipe. |
| 05_tables_occupees.sql | Chaque table indique sa note en cours : les serveuses voient les tables déjà prises. |
| 06_remise_a_zero.sql | Remise à zéro par le patron (garde menu, tables fixes, équipe, réglages). |
| 07_powersync.sql | Accès de PowerSync (remplacer le mot de passe avant de lancer). |
| 08_licences_abonnement.sql | Abonnement par club, blocage + grâce, espace admin, **création d'un club + son patron**. |
| 09_admin_plateforme.sql | T'enregistrer comme administrateur (remplacer VOTRE_EMAIL_ICI). |

## Après les scripts

1. **Ton compte admin** : crée-le dans Authentication > Users (e-mail + mot de passe,
   coche *Auto Confirm User*), puis lance le script 09 avec ce même e-mail.

2. **PowerSync** : dans le tableau de bord PowerSync, colle `POWERSYNC/sync_rules.yaml`
   dans *Sync Streams* puis *Deploy*. Mets le mot de passe choisi au script 07.

3. **Réglage Supabase** : Authentication > Sign In / Providers > Email :
   désactive « Allow new users to sign up ». Les comptes sont créés uniquement
   par l'admin (toi) et par les patrons.

## Créer un club (toi, l'administrateur)

Depuis l'espace admin (ou dans le SQL Editor) :

```sql
select public.admin_create_club(
  'Le Palace',        -- nom du club
  'patron',           -- identifiant du patron
  '123456',           -- code PIN du patron (6 chiffres)
  'Nom du patron',    -- nom affiché
  '90 00 00 00',      -- téléphone (facultatif)
  1,                  -- nombre de mois d'abonnement au départ (12 pour l'année)
  25000               -- prix mensuel en FCFA
);
```

La fonction renvoie le **code du club** (6 lettres/chiffres) : donne-le au client.
Sur chaque appareil, il le saisit une fois, puis se connecte avec identifiant + PIN.
Le patron crée ensuite ses gérants et ses serveuses depuis le logiciel.

## Principales fonctions

| Qui | Fonctions |
| --- | --- |
| Serveuse | open_tab, add_items, cancel_request, request_payment, reopen_tab, create_table |
| Gérant | open_night, close_night, serve_items, refuse_items, remove_item, record_payment, cancel_tab, add_cash_movement, record_expense, receive_stock, adjust_stock, record_inventory, stock_overview, night_report |
| Patron | tout ce que fait le gérant + create_member, set_member_pin, update_member, set_member_active, delete_member, change_my_credentials, reset_club |
| Admin (toi) | admin_create_club, admin_clubs, admin_club_detail, admin_overview, admin_record_payment, admin_extend, admin_set_expiry, admin_set_suspended, admin_set_price, admin_reset_patron_pin, admin_delete_club |
| Tous | subscription_status (état de l'abonnement), club_by_code (mise en place de l'appareil) |
