-- ============================================================
-- Hair Studios – Security Patch 2 (privacy + anti doppia prenotazione)
-- Esegui nel SQL Editor di Supabase DOPO aver deployato il
-- frontend aggiornato (usa la RPC get_busy_slots).
-- ============================================================

-- 1. RPC per il controllo disponibilità slot
--    Restituisce SOLO i dati minimi (niente nomi, telefoni, note, guadagni)
CREATE OR REPLACE FUNCTION public.get_busy_slots(from_date date DEFAULT CURRENT_DATE)
RETURNS TABLE(staff_id integer, date date, "time" time, service_duration integer)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT b.staff_id, b.date, b."time", b.service_duration
  FROM public.bookings b
  WHERE b.status != 'cancelled'
    AND b.date >= from_date;
$$;

REVOKE ALL ON FUNCTION public.get_busy_slots(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_busy_slots(date) TO authenticated;

-- 2. Restringe la lettura delle prenotazioni:
--    i clienti vedono SOLO le proprie (gli admin vedono tutto
--    grazie alla policy "bookings: admin tutto" già esistente)
DROP POLICY IF EXISTS "bookings: leggi tutte se autenticato" ON public.bookings;
DROP POLICY IF EXISTS "bookings: leggi le proprie" ON public.bookings;
CREATE POLICY "bookings: leggi le proprie" ON public.bookings
  FOR SELECT USING (auth.uid() = user_id);

-- 3. Indice unico anti doppia prenotazione sullo stesso slot
--    (stesso barbiere, stessa data, stessa ora, non cancellata)
--    NOTA: se fallisce per duplicati storici, trovali con la query
--    in fondo e sistemali prima di rilanciare.
CREATE UNIQUE INDEX IF NOT EXISTS bookings_slot_unique
  ON public.bookings (staff_id, date, "time")
  WHERE status != 'cancelled';

-- ============================================================
-- VERIFICA DUPLICATI (esegui solo se il punto 3 fallisce)
-- ============================================================
-- SELECT staff_id, date, "time", COUNT(*), ARRAY_AGG(id)
-- FROM public.bookings
-- WHERE status != 'cancelled'
-- GROUP BY staff_id, date, "time"
-- HAVING COUNT(*) > 1;
