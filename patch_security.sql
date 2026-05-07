-- ============================================================
-- Hair Studios – Security Patch
-- Esegui tutto nel SQL Editor di Supabase
-- ============================================================

-- ── FIX 1: Blocca auto-escalation su profiles ───────────────
-- La policy originale permetteva a chiunque di aggiornarsi is_admin.
-- La nuova WITH CHECK impedisce di modificare quel campo.

DROP POLICY IF EXISTS "profiles: modifica il proprio" ON public.profiles;

CREATE POLICY "profiles: modifica il proprio" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    -- is_admin non può cambiare: il nuovo valore deve essere uguale all'attuale
    AND is_admin = (SELECT is_admin FROM public.profiles WHERE id = auth.uid())
  );


-- ── FIX 2: Forza status='pending' sulle nuove prenotazioni ──
-- Impedisce a un utente di inserire una prenotazione già confermata.

DROP POLICY IF EXISTS "bookings: inserisci le proprie" ON public.bookings;

CREATE POLICY "bookings: inserisci le proprie" ON public.bookings
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND status = 'pending'
  );


-- ── FIX 3: Revoca admin agli utenti non autorizzati ─────────
-- Esegui questa query per vedere chi ha is_admin = true:
--
--   SELECT id, name, created_at
--   FROM public.profiles
--   WHERE is_admin = TRUE;
--
-- Se trovi utenti non autorizzati, revoca con:
--
--   UPDATE public.profiles
--   SET is_admin = FALSE
--   WHERE id = 'UUID_UTENTE_NON_AUTORIZZATO';
