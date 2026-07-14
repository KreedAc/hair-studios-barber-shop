-- ============================================================
-- Hair Studios – Notifiche Push (Web Push)
-- Esegui nel SQL Editor di Supabase.
-- La FASE 2 (promemoria) è in fondo ed è facoltativa/successiva.
-- ============================================================

-- 1. Iscrizioni push dei dispositivi (una riga per dispositivo/browser)
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id         BIGSERIAL   PRIMARY KEY,
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  endpoint   TEXT        NOT NULL UNIQUE,
  p256dh     TEXT        NOT NULL,
  auth       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS push_subscriptions_user_idx ON public.push_subscriptions(user_id);

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Ognuno gestisce solo le proprie iscrizioni (la Edge Function usa la
-- service role e bypassa la RLS per leggere quelle dei destinatari)
DROP POLICY IF EXISTS "push: gestisci le proprie" ON public.push_subscriptions;
CREATE POLICY "push: gestisci le proprie" ON public.push_subscriptions
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 2. Colonna per non inviare due volte il promemoria
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS reminder_sent BOOLEAN NOT NULL DEFAULT FALSE;

-- ============================================================
-- FASE 2 · PROMEMORIA AUTOMATICI (esegui dopo aver verificato
-- che le notifiche evento funzionano)
-- ------------------------------------------------------------
-- Invia un promemoria per gli appuntamenti confermati che cadono
-- entro le prossime 24 ore. Richiede le estensioni pg_cron e pg_net
-- e il secret con l'URL/chiave del progetto.
-- ============================================================

-- Abilita le estensioni (Database → Extensions, oppure qui)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- CREATE EXTENSION IF NOT EXISTS pg_net;

-- Funzione che scandisce gli appuntamenti e chiama la Edge Function
-- send-push per ognuno. SOSTITUISCI <PROJECT_REF> e <SERVICE_ROLE_KEY>.
-- CREATE OR REPLACE FUNCTION public.send_due_reminders()
-- RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
-- DECLARE r RECORD;
-- BEGIN
--   FOR r IN
--     SELECT id FROM public.bookings
--     WHERE status = 'confirmed' AND reminder_sent = FALSE
--       AND (date + "time") AT TIME ZONE 'Europe/Rome'
--           BETWEEN now() AND now() + interval '24 hours'
--   LOOP
--     PERFORM net.http_post(
--       url     := 'https://pzdnvygxnosmxrjfjvsv.supabase.co/functions/v1/send-push',
--       headers := jsonb_build_object(
--         'Content-Type','application/json',
--         'Authorization','Bearer <SERVICE_ROLE_KEY>'
--       ),
--       body    := jsonb_build_object('booking_id', r.id, 'event', 'reminder')
--     );
--     UPDATE public.bookings SET reminder_sent = TRUE WHERE id = r.id;
--   END LOOP;
-- END;
-- $$;

-- Pianifica il job ogni ora
-- SELECT cron.schedule('hair-studios-reminders', '0 * * * *',
--   $$ SELECT public.send_due_reminders(); $$);
