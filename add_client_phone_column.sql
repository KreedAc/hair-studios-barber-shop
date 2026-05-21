-- Aggiunge il campo telefono alle prenotazioni (per inserimenti manuali)
-- Esegui nel SQL Editor di Supabase

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS client_phone TEXT;
