# AdMob SSV (rewarded 2×)

Deploy after applying `migration_security_round3_fixes.sql`:

```bash
supabase functions deploy admob-ssv --no-verify-jwt
```

In AdMob → rewarded ad unit → Server-side verification callback URL:

`https://<project-ref>.supabase.co/functions/v1/admob-ssv`

The Flutter app sets:

- `user_id` = Supabase auth user id
- `custom_data` = prepare session UUID

Local/dev without SSV (SQL Editor session):

```sql
select set_config('app.ad_double_allow_client_attest', 'true', false);
```
