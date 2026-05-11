-- Aggiunge il campo guadagno alle prenotazioni
-- Esegui nel SQL Editor di Supabase

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS earnings NUMERIC(8,2);
