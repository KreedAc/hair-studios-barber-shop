-- ============================================================
-- Hair Studios – Token push nativi (Capacitor FCM/APNs)
-- Esegui nel SQL Editor di Supabase.
-- Complementa push_subscriptions (web push): qui stanno i token
-- dei dispositivi che usano l'app nativa.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.push_tokens (
  id         BIGSERIAL   PRIMARY KEY,
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token      TEXT        NOT NULL UNIQUE,
  platform   TEXT        NOT NULL DEFAULT 'android',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS push_tokens_user_idx ON public.push_tokens(user_id);

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

-- Ognuno gestisce solo i propri token (la Edge Function usa la service
-- role e bypassa la RLS per leggere quelli dei destinatari)
DROP POLICY IF EXISTS "push_tokens: gestisci i propri" ON public.push_tokens;
CREATE POLICY "push_tokens: gestisci i propri" ON public.push_tokens
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
