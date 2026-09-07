-- Replace these values before running this file in Supabase SQL Editor:
-- PROJECT_URL example: https://your-project-ref.supabase.co
-- CRON_SECRET should be a long random string also configured in the Edge Function.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select vault.create_secret('PROJECT_URL', 'sqlive_project_url');
select vault.create_secret('CRON_SECRET', 'sqlive_cron_secret');

select cron.schedule(
  'sqlive-eldergrove-tick-every-minute',
  '* * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'sqlive_project_url') || '/functions/v1/tick-world',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'sqlive_cron_secret')
    ),
    body := '{"world_slug":"eldergrove"}'::jsonb
  );
  $$
);

