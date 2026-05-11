-- Aggiunge il campo note alle prenotazioni
-- Esegui nel SQL Editor di Supabase

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS notes TEXT;
