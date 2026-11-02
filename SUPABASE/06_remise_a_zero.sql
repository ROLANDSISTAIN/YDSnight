-- =====================================================================
-- YDS NIGHT · Script 06 · Remise a zero (patron seulement)
-- Efface l'activite de SON club : soirees, notes, boissons servies,
-- paiements, depenses, mouvements de caisse, tables provisoires.
-- Option : remettre aussi le stock a zero (entrees, pertes, inventaires).
-- Toujours gardes : le menu, les prix, les tables fixes, l'equipe, les reglages.
-- Les recus repartent naturellement a 1 (le numero est propre au club).
-- Utilisee depuis le logiciel : Reglages > Remettre a zero.
-- =====================================================================

create or replace function public.reset_club(p_confirmation text, p_stock boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_club uuid := public.my_club(); v_notes int; v_soirees int;
begin
  if not public.is_patron() then raise exception 'Seul le patron peut remettre le logiciel a zero'; end if;
  if coalesce(upper(trim(p_confirmation)), '') <> 'EFFACER' then
    raise exception 'Confirmation incorrecte : tapez EFFACER';
  end if;

  select count(*) into v_notes from public.tabs where club_id = v_club;
  select count(*) into v_soirees from public.nights where club_id = v_club;

  if p_stock then
    delete from public.stock_movements where club_id = v_club;
    delete from public.stock_entries where club_id = v_club;
    delete from public.inventories where club_id = v_club;
  else
    -- Le stock reste juste : les sorties deja comptees sont gardees, sans lien vers les notes effacees.
    update public.stock_movements set tab_item_id = null where club_id = v_club and tab_item_id is not null;
  end if;

  delete from public.payments where club_id = v_club;
  delete from public.tab_items where club_id = v_club;
  delete from public.tabs where club_id = v_club;
  delete from public.cash_movements where club_id = v_club;
  delete from public.expenses where club_id = v_club;
  delete from public.nights where club_id = v_club;

  update public.club_tables set current_tab_id = null where club_id = v_club and current_tab_id is not null;
  delete from public.club_tables where club_id = v_club and not is_fixed;

  return jsonb_build_object('notes_effacees', v_notes, 'soirees_effacees', v_soirees, 'stock_remis_a_zero', p_stock);
end $$;

revoke execute on function public.reset_club(text, boolean) from public, anon;
grant execute on function public.reset_club(text, boolean) to authenticated;
