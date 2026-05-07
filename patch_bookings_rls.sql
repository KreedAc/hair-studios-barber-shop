-- ============================================================
-- Hair Studios – Bookings RLS Patch
-- Permette a tutti gli utenti autenticati di leggere tutte
-- le prenotazioni (necessario per il controllo disponibilità slot)
-- Esegui nel SQL Editor di Supabase
-- ============================================================

SET ROLE postgres;

DROP POLICY IF EXISTS "bookings: leggi le proprie o admin" ON public.bookings;

CREATE POLICY "bookings: leggi tutte se autenticato" ON public.bookings
  FOR SELECT USING (auth.uid() IS NOT NULL);
