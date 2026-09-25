-- Stat: CASS + CAM pe linie; conturi 4315 / 4316 / 6461 / 436 pentru nota NextUp.

ALTER TABLE public.hr_settings
    ALTER COLUMN cas_account SET DEFAULT '4315';

ALTER TABLE public.hr_settings
    ADD COLUMN IF NOT EXISTS cass_account TEXT NOT NULL DEFAULT '4316',
    ADD COLUMN IF NOT EXISTS cam_expense_account TEXT NOT NULL DEFAULT '6461',
    ADD COLUMN IF NOT EXISTS cam_account TEXT NOT NULL DEFAULT '436';

UPDATE public.hr_settings
SET cas_account = '4315'
WHERE cas_account = '431';

ALTER TABLE public.hr_payroll_lines
    ADD COLUMN IF NOT EXISTS cass_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cam_amount NUMERIC(18, 2) NOT NULL DEFAULT 0;
