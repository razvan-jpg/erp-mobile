-- Încasări POS de la ultimul Z, pe punct de lucru.

CREATE TABLE public.pos_shift_takings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    work_location_id UUID NOT NULL REFERENCES public.company_work_locations(id) ON DELETE CASCADE,
    channel TEXT NOT NULL CHECK (channel IN ('cash', 'card', 'glovo', 'bolt', 'wolt')),
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    z_closed_at TIMESTAMPTZ
);

CREATE INDEX pos_shift_takings_open
    ON public.pos_shift_takings (company_id, work_location_id)
    WHERE z_closed_at IS NULL;

ALTER TABLE public.pos_shift_takings ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.pos_operator_can_record()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        private.is_current_user_superadmin()
        OR private.is_current_user_company_admin()
        OR EXISTS (
            SELECT 1
            FROM public.user_module_permissions ump
            JOIN public.modules m ON m.id = ump.module_id
            WHERE ump.user_id = auth.uid()
              AND m.code IN ('cashier', 'sales')
              AND m.is_active = true
              AND ump.can_create
        );
$$;

CREATE POLICY "pos_shift_takings_select" ON public.pos_shift_takings
    FOR SELECT TO authenticated
    USING (
        company_id = private.current_user_selected_company_id()
        AND public.pos_operator_can_record()
    );

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.pos_shift_takings TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_operator_can_record() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.pos_record_taking(
    p_work_location_id uuid,
    p_channel text,
    p_amount text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
    v_channel text;
    v_amount numeric;
BEGIN
    IF NOT public.pos_operator_can_record() THEN
        RAISE EXCEPTION 'Nu aveți dreptul să înregistrați încasarea';
    END IF;

    v_company := private.current_user_selected_company_id();
    IF v_company IS NULL THEN
        RAISE EXCEPTION 'Selectați o societate';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.company_work_locations
        WHERE id = p_work_location_id
          AND company_id = v_company
    ) THEN
        RAISE EXCEPTION 'Punctul de lucru nu aparține societății active';
    END IF;

    v_channel := lower(btrim(p_channel));
    IF v_channel NOT IN ('cash', 'card', 'glovo', 'bolt', 'wolt') THEN
        RAISE EXCEPTION 'Modul de încasare nu este recunoscut';
    END IF;

    v_amount := round(replace(btrim(p_amount), ',', '.')::numeric, 2);
    IF v_amount <= 0 THEN
        RETURN;
    END IF;

    INSERT INTO public.pos_shift_takings (company_id, work_location_id, channel, amount)
    VALUES (v_company, p_work_location_id, v_channel, v_amount);
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_open_takings(p_work_location_id uuid)
RETURNS TABLE(cash numeric, card numeric, glovo numeric, bolt numeric, wolt numeric)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
BEGIN
    IF NOT public.pos_operator_can_record() THEN
        RAISE EXCEPTION 'Nu aveți dreptul să vedeți încasările';
    END IF;

    v_company := private.current_user_selected_company_id();
    IF v_company IS NULL THEN
        RAISE EXCEPTION 'Selectați o societate';
    END IF;

    RETURN QUERY
    SELECT
        COALESCE(SUM(t.amount) FILTER (WHERE t.channel = 'cash'), 0),
        COALESCE(SUM(t.amount) FILTER (WHERE t.channel = 'card'), 0),
        COALESCE(SUM(t.amount) FILTER (WHERE t.channel = 'glovo'), 0),
        COALESCE(SUM(t.amount) FILTER (WHERE t.channel = 'bolt'), 0),
        COALESCE(SUM(t.amount) FILTER (WHERE t.channel = 'wolt'), 0)
    FROM public.pos_shift_takings t
    WHERE t.company_id = v_company
      AND t.work_location_id = p_work_location_id
      AND t.z_closed_at IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_close_takings_z(p_work_location_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
BEGIN
    IF NOT public.pos_operator_can_record() THEN
        RAISE EXCEPTION 'Nu aveți dreptul să închideți ziua';
    END IF;

    v_company := private.current_user_selected_company_id();
    IF v_company IS NULL THEN
        RAISE EXCEPTION 'Selectați o societate';
    END IF;

    UPDATE public.pos_shift_takings
    SET z_closed_at = now()
    WHERE company_id = v_company
      AND work_location_id = p_work_location_id
      AND z_closed_at IS NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.pos_record_taking(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_open_takings(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_close_takings_z(uuid) TO authenticated, service_role;
