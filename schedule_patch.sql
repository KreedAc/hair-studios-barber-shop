-- ============================================================
-- Hair Studios – Schedule Patch
-- Esegui tutto nel SQL Editor di Supabase (con SET ROLE postgres)
-- ============================================================

SET ROLE postgres;

-- ── 1. Aggiungi colonna weekly_config a staff_schedules ─────────
ALTER TABLE public.staff_schedules
  ADD COLUMN IF NOT EXISTS weekly_config JSONB;

-- ── 2. Imposta l'orario del salone su tutti i barbieri ──────────
-- Dom(0) e Lun(1) = chiuso
-- Mar(2)–Ven(5)  = 09:30–19:30, pausa 12:30–15:00
-- Sab(6)         = 09:30–18:00, pausa 13:00–14:00
UPDATE public.staff_schedules SET weekly_config = '{
  "0": null,
  "1": null,
  "2": {"start":"09:30","end":"19:30","breaks":[{"start":"12:30","end":"15:00"}]},
  "3": {"start":"09:30","end":"19:30","breaks":[{"start":"12:30","end":"15:00"}]},
  "4": {"start":"09:30","end":"19:30","breaks":[{"start":"12:30","end":"15:00"}]},
  "5": {"start":"09:30","end":"19:30","breaks":[{"start":"12:30","end":"15:00"}]},
  "6": {"start":"09:30","end":"18:00","breaks":[{"start":"13:00","end":"14:00"}]}
}'::jsonb;

-- ── 3. Crea tabella pause extra su date specifiche ──────────────
CREATE TABLE IF NOT EXISTS public.staff_day_blocks (
  id         SERIAL      PRIMARY KEY,
  staff_id   INTEGER     NOT NULL REFERENCES public.staff(id) ON DELETE CASCADE,
  date       DATE        NOT NULL,
  start_time TIME        NOT NULL,
  end_time   TIME        NOT NULL,
  label      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.staff_day_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "day_blocks: lettura pubblica" ON public.staff_day_blocks;
DROP POLICY IF EXISTS "day_blocks: admin scrittura"  ON public.staff_day_blocks;

CREATE POLICY "day_blocks: lettura pubblica" ON public.staff_day_blocks FOR SELECT USING (TRUE);
CREATE POLICY "day_blocks: admin scrittura"  ON public.staff_day_blocks FOR ALL    USING (public.is_admin());
