-- ============================================================
-- Hair Studios – Security Patch
-- Applicata il 2026-05-11
-- Eseguita nel SQL Editor di Supabase
-- ============================================================

-- 1. BLOCCA ESCALATION PRIVILEGI
--    Impedisce a utenti normali di modificare is_admin e staff_id
--    tramite update diretto sull'API Supabase
CREATE OR REPLACE FUNCTION public.prevent_privilege_escalation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_admin() THEN
    NEW.is_admin := OLD.is_admin;
    NEW.staff_id := OLD.staff_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS no_privilege_escalation ON public.profiles;
CREATE TRIGGER no_privilege_escalation
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_privilege_escalation();

-- 2. FIX BOOKING INSERT
--    Un utente può inserire solo prenotazioni con il proprio user_id
DROP POLICY IF EXISTS "bookings: inserisci le proprie" ON public.bookings;
CREATE POLICY "bookings: inserisci le proprie" ON public.bookings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 3. LIMITA LETTURA SCHEDULES E DAY BLOCKS AGLI AUTENTICATI
DROP POLICY IF EXISTS "schedules: lettura pubblica" ON public.staff_schedules;
CREATE POLICY "schedules: lettura autenticati" ON public.staff_schedules
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "day_blocks: lettura pubblica" ON public.staff_day_blocks;
CREATE POLICY "day_blocks: lettura autenticati" ON public.staff_day_blocks
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ============================================================
-- VERIFICA (eseguire separatamente)
-- ============================================================
-- SELECT trigger_name, event_manipulation, action_timing
-- FROM information_schema.triggers
-- WHERE event_object_table = 'profiles';
--
-- SELECT policyname, cmd, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'bookings';
