-- ============================================================
-- Hair Studios – RLS: annullo prenotazioni da parte del cliente
-- Esegui nel SQL Editor di Supabase.
--
-- Prima il cliente poteva annullare SOLO le prenotazioni "in attesa"
-- (la vecchia policy aveva USING status = 'pending'), quindi l'annullo
-- delle CONFERMATE veniva rifiutato in silenzio (0 righe, nessun errore).
--
-- Ora il cliente può annullare le PROPRIE prenotazioni:
--   - "in attesa"  → sempre
--   - "confermate" → solo se mancano PIÙ di 2 ore all'orario
-- Il nuovo stato può essere solo 'cancelled', e non può cambiare user_id.
-- ============================================================

DROP POLICY IF EXISTS "bookings: cancella le proprie pending" ON public.bookings;

CREATE POLICY "bookings: annulla le proprie" ON public.bookings
  FOR UPDATE
  USING (
    auth.uid() = user_id AND (
      status = 'pending'
      OR (status = 'confirmed'
          AND (date + "time") AT TIME ZONE 'Europe/Rome' > now() + interval '2 hours')
    )
  )
  WITH CHECK (auth.uid() = user_id AND status = 'cancelled');
