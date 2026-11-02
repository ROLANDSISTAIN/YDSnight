# Banc de test local (facultatif)

Vérifie que les scripts se chargent et que le fonctionnement est correct,
sans toucher à Supabase. Nécessite PostgreSQL installé localement.

```bash
createdb ydsnight_test
psql -d ydsnight_test -f test/mock_supabase.sql     # imitation minimale de Supabase
for f in 01_tables 02_droits 03_fonctions 04_comptes 05_tables_occupees \
         06_remise_a_zero 07_powersync 08_licences_abonnement; do
  psql -v ON_ERROR_STOP=1 -d ydsnight_test -f $f.sql
done
psql -d ydsnight_test -f test/test_flow.sql         # soirée complète + isolation + blocage
```

`test_flow.sql` crée deux clubs, déroule une soirée (serveuse → bar → caisse),
vérifie l'isolation entre clubs et le blocage d'abonnement (grâce de 7 jours).
