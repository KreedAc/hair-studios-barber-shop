-- ============================================================
-- Hair Studios – Tabella override orario su singola data
-- Permette di sovrascrivere l'orario settimanale per un giorno
-- specifico (es. apertura straordinaria di domenica, orari diversi)
-- Esegui nel SQL Editor di Supabase
-- ============================================================

CREATE TABLE IF NOT EXISTS public.staff_day_overrides (
  id          SERIAL PRIMARY KEY,
  staff_id    INTEGER REFERENCES public.staff(id) ON DELETE CASCADE,
  date        DATE NOT NULL,
  start_time  TIME,                     -- null = giorno chiuso
  end_time    TIME,
  breaks      JSONB DEFAULT '[]'::jsonb, -- [{start:"12:00", end:"13:00"}]
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(staff_id, date)
);

ALTER TABLE public.staff_day_overrides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "day_overrides: lettura autenticati" ON public.staff_day_overrides;
CREATE POLICY "day_overrides: lettura autenticati"
  ON public.staff_day_overrides
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "day_overrides: admin scrittura" ON public.staff_day_overrides;
CREATE POLICY "day_overrides: admin scrittura"
  ON public.staff_day_overrides
  FOR ALL USING (is_admin());
