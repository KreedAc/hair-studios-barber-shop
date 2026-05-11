-- ============================================================
-- Hair Studios – Setup Subadmin
-- Collega i profili admin ai rispettivi profili staff via email
-- Esegui nel SQL Editor di Supabase
-- ============================================================

-- 1. Aggiungi colonna staff_id ai profili (se non esiste)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS staff_id UUID REFERENCES public.staff(id);

-- 2. Auto-associa subadmin ↔ staff tramite email
--    Funziona se nella tabella staff hai già inserito l'email di ogni barbiere
UPDATE public.profiles p
SET staff_id = s.id
FROM public.staff s
JOIN auth.users u ON u.email = s.email
WHERE u.id = p.id
  AND p.staff_id IS NULL;

-- 3. Verifica il risultato (esegui separatamente per controllare)
-- SELECT p.id, u.email, p.is_admin, p.staff_id, s.name
-- FROM public.profiles p
-- JOIN auth.users u ON u.id = p.id
-- LEFT JOIN public.staff s ON s.id = p.staff_id
-- WHERE p.is_admin = true;
