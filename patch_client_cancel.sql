-- ============================================================
-- Hair Studios – Annullamento cliente (anche se confermata)
-- Regola: annullabile fino a 2 ore prima dell'appuntamento.
-- Esegui nel SQL Editor di Supabase PRIMA di deployare il
-- frontend aggiornato (che usa la RPC cancel_own_booking).
-- ============================================================

-- 1. Colonne di tracciamento: quando e da chi è stata annullata
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancelled_by TEXT
    CHECK (cancelled_by IN ('client','staff'));

-- 1b. Chat ID Telegram del barbiere (per la notifica di annullamento).
--     Si imposta dall'app: Team → profilo barbiere → "Telegram Chat ID".
ALTER TABLE public.staff
  ADD COLUMN IF NOT EXISTS telegram_chat_id TEXT;

-- 2. RPC di annullamento lato cliente.
--    La regola delle 2 ore è verificata QUI, lato server:
--    anche chiamando l'API a mano non si può aggirare.
CREATE OR REPLACE FUNCTION public.cancel_own_booking(p_booking_id integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  bk public.bookings%ROWTYPE;
BEGIN
  SELECT * INTO bk
  FROM public.bookings
  WHERE id = p_booking_id AND user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prenotazione non trovata';
  END IF;

  IF bk.status = 'cancelled' THEN
    RAISE EXCEPTION 'Prenotazione già annullata';
  END IF;

  -- date/time delle prenotazioni sono in ora italiana
  IF (bk.date + bk."time") <= (now() AT TIME ZONE 'Europe/Rome') + interval '2 hours' THEN
    RAISE EXCEPTION 'L''appuntamento si può annullare solo fino a 2 ore prima';
  END IF;

  UPDATE public.bookings
  SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'client'
  WHERE id = p_booking_id;
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_own_booking(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_own_booking(integer) TO authenticated;

-- 3. La vecchia policy permetteva l'update diretto solo delle 'pending':
--    ora tutti gli annullamenti cliente passano dalla RPC (che applica
--    la regola delle 2 ore), quindi la policy si può rimuovere.
DROP POLICY IF EXISTS "bookings: cancella le proprie pending" ON public.bookings;

-- ============================================================
-- VERIFICA (eseguire separatamente)
-- ============================================================
-- SELECT proname FROM pg_proc WHERE proname = 'cancel_own_booking';
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'bookings' AND column_name LIKE 'cancelled%';
