-- ============================================================================
-- DRAFT MIGRATION — NOT EXECUTED ON LIVE DATABASE
-- Requires explicit written user approval before running against Supabase.
-- Backup already saved locally: supabase_backup_2026-11-11.json
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SECTION 1: READ-ONLY DRY-RUN PREVIEW (Run this FIRST to inspect exact rows)
-- ----------------------------------------------------------------------------
SELECT 'letters' AS tbl, id, space_id, title, author,
       CASE
         WHEN id = 'letter_1792595996898' THEN 'Asmon:::cZsqRd9TB7WdeqmPqrDP4zwDATn2'
         WHEN author = 'Asmon:::ZD412xzX5uP1dyJTgqhnkT2Jzl13' THEN 'Asmon:::cZsqRd9TB7WdeqmPqrDP4zwDATn2'
         WHEN author = 'ZD412xzX5uP1dyJTgqhnkT2Jzl13' THEN 'Asmon:::cZsqRd9TB7WdeqmPqrDP4zwDATn2'
         ELSE author
       END AS proposed_author,
       'space_1793369981266' AS proposed_space_id
FROM public.letters
WHERE author IN ('asmon', 'ZD412xzX5uP1dyJTgqhnkT2Jzl13', 'Asmon:::ZD412xzX5uP1dyJTgqhnkT2Jzl13');

SELECT 'milestones' AS tbl, id, space_id, title, author,
       'Asmon:::cZsqRd9TB7WdeqmPqrDP4zwDATn2' AS proposed_author,
       'space_1793369981266' AS proposed_space_id
FROM public.milestones
WHERE author IN ('ZD412xzX5uP1dyJTgqhnkT2Jzl13', 'Asmon:::ZD412xzX5uP1dyJTgqhnkT2Jzl13');

-- Verify third-party/Mom account rows stay untouched:
SELECT 'untouched_other_accounts' AS check_type, id, space_id, title, author
FROM public.memories
WHERE space_id = 'space_1792935177904';

-- ----------------------------------------------------------------------------
-- SECTION 2: OWNER & SPACE BACKFILL (Run ONLY inside transaction after approval)
-- ----------------------------------------------------------------------------
BEGIN;

-- 1. Re-attribute Asmon's 3 legacy letters to canonical Asmon Firebase UID:
UPDATE public.letters
SET author = 'Asmon:::cZsqRd9TB7WdeqmPqrDP4zwDATn2',
    space_id = 'space_1793369981266'
WHERE id IN (
  'letter_1792595996898',           -- "FOR U" (was author='asmon')
  'let_1792940365525',              -- "old letter i wrote for you" (was ZD412...)
  'letter_1792785258746_l2cks6'     -- "Kuchupuchu" (was Asmon:::ZD412...)
);

-- 2. Re-attribute Asmon's 4 legacy milestones & align them to active couple space:
UPDATE public.milestones
SET author = 'Asmon:::cZsqRd9TB7WdeqmPqrDP4zwDATn2',
    space_id = 'space_1793369981266'
WHERE id IN (
  'milestone_1792785343540_5grox7', -- "1st day of my app"
  'milestone_1792785403908_6admt2', -- "Meaow leave me alone 💔"
  'mls_1792940493197',              -- "planning how to go meet with zoobi"
  'mls_1793169976088'               -- "suck day"
);

-- 3. Clear uncompleted preset goal leftover label ("Toufiq Ahmed" where isCompleted = false):
UPDATE public.app_content
SET content = (
  SELECT jsonb_agg(
    CASE
      WHEN (elem->>'id') IN ('preset_1', 'preset_2')
           AND COALESCE((elem->>'isCompleted')::boolean, false) = false
      THEN jsonb_set(elem, '{completedBy}', 'null'::jsonb)
      ELSE elem
    END
  )
  FROM jsonb_array_elements(content) AS elem
),
    updated_at = NOW()
WHERE id = 'couple_goals_space_1793369981266'
  AND jsonb_typeof(content) = 'array';

COMMIT;

-- ----------------------------------------------------------------------------
-- SECTION 3: RLS HARDENING TEMPLATE (DO NOT ENABLE UNTIL FIREBASE JWT BRIDGE IS ACTIVE)
-- ----------------------------------------------------------------------------
-- IMPORTANT ARCHITECTURAL WARNING:
-- The mobile app authenticates with Firebase Auth (UIDs like cZsqRd9TB7WdeqmPqrDP4zwDATn2),
-- NOT Supabase Auth JWTs (`auth.uid()` is currently NULL on Supabase queries).
-- Before applying these RLS policies:
--   1. Enable Firebase Third-Party Auth in Supabase Dashboard (Auth -> Providers -> Firebase)
--      AND call Supabase `accessToken` callback using `FirebaseAuth.instance.currentUser?.getIdToken()`, OR
--   2. Backfill `public.spaces` in Supabase with all Firestore couple spaces (including space_1793369981266).
--
-- Once Firebase JWTs are verified by Supabase (`auth.jwt()->>'sub'` = Firebase UID):
--
-- ALTER TABLE public.memories ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.letters ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.milestones ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.spaces ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.app_content ENABLE ROW LEVEL SECURITY;
--
-- DROP POLICY IF EXISTS "Allow all memories" ON public.memories;
-- DROP POLICY IF EXISTS "Allow authenticated memories access" ON public.memories;
-- CREATE POLICY "memories_couple_read" ON public.memories FOR SELECT
--   USING (EXISTS (
--     SELECT 1 FROM public.spaces s
--     WHERE s.id = memories.space_id
--       AND (s.creator_id = (auth.jwt()->>'sub') OR s.partner_id = (auth.jwt()->>'sub'))
--   ));
-- CREATE POLICY "memories_owner_insert" ON public.memories FOR INSERT
--   WITH CHECK (split_part(author, ':::', 2) = (auth.jwt()->>'sub') OR author = (auth.jwt()->>'sub'));
-- CREATE POLICY "memories_owner_delete" ON public.memories FOR DELETE
--   USING (split_part(author, ':::', 2) = (auth.jwt()->>'sub') OR author = (auth.jwt()->>'sub'));
--
-- (Repeat matching member read + owner insert/delete policies for public.letters and public.milestones.)
