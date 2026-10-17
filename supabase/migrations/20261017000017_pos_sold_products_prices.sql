-- Raport produse: pret de vanzare, total pe linie si grupa din catalog.
-- Un produs aflat in doua grupe intra o singura data, in prima grupa,
-- ca subtotalurile sa dea totalul general.

DROP FUNCTION IF EXISTS public.pos_sold_products(uuid, uuid);

CREATE FUNCTION public.pos_sold_products(
    p_work_location_id uuid,
    p_sheet_id uuid
)
RETURNS TABLE (
    grupa text,
    grupa_ordine integer,
    cod text,
    denumire text,
    um text,
    cantitate numeric,
    pret numeric,
    valoare numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company uuid;
    v_from timestamptz;
    v_to timestamptz;
BEGIN
    IF NOT (
        private.is_current_user_superadmin()
        OR private.is_current_user_company_admin()
        OR EXISTS (
            SELECT 1
              FROM public.user_module_permissions ump
              JOIN public.modules m ON m.id = ump.module_id
             WHERE ump.user_id = auth.uid()
               AND m.code = 'cashier'
               AND m.is_active = true
               AND ump.can_view
        )
    ) THEN
        RAISE EXCEPTION 'Nu aveți dreptul să vedeți produsele vândute';
    END IF;

    v_company := private.current_user_selected_company_id();
    IF v_company IS NULL THEN
        RAISE EXCEPTION 'Selectați o societate';
    END IF;

    IF p_work_location_id IS NULL OR NOT EXISTS (
        SELECT 1
          FROM public.company_work_locations loc
         WHERE loc.id = p_work_location_id
           AND loc.company_id = v_company
    ) THEN
        RAISE EXCEPTION 'Punctul de lucru nu aparține societății active';
    END IF;

    IF NOT private.station_location_allowed(p_work_location_id) THEN
        RAISE EXCEPTION 'Nu aveți dreptul pe acest punct de lucru';
    END IF;

    IF p_sheet_id IS NULL THEN
        SELECT sheet.created_at
          INTO v_from
          FROM public.z_stock_sheets sheet
         WHERE sheet.company_id = v_company
           AND sheet.work_location_id = p_work_location_id
         ORDER BY sheet.created_at DESC
         LIMIT 1;
        v_to := NULL;
    ELSE
        SELECT sheet.created_at
          INTO v_to
          FROM public.z_stock_sheets sheet
         WHERE sheet.id = p_sheet_id
           AND sheet.company_id = v_company
           AND sheet.work_location_id = p_work_location_id;

        IF v_to IS NULL THEN
            RAISE EXCEPTION 'Raportul Z nu aparține punctului de lucru';
        END IF;

        SELECT sheet.created_at
          INTO v_from
          FROM public.z_stock_sheets sheet
         WHERE sheet.company_id = v_company
           AND sheet.work_location_id = p_work_location_id
           AND sheet.created_at < v_to
         ORDER BY sheet.created_at DESC
         LIMIT 1;
    END IF;

    RETURN QUERY
    WITH sold AS (
        SELECT
            p.id AS product_id,
            p.tip AS tip,
            COALESCE(p.cod, '') AS cod,
            p.denumire,
            COALESCE(NULLIF(sm.unitate_masura, ''), 'buc') AS um,
            CASE
                WHEN sm.canal = 'online' AND COALESCE(p.pret_vanzare_online, 0) > 0 THEN p.pret_vanzare_online
                ELSE COALESCE(p.pret_vanzare, 0)
            END AS pret,
            SUM(sm.cantitate) AS cantitate
          FROM public.stock_movements sm
          JOIN public.products p ON p.id = sm.product_id
          JOIN public.company_warehouses w ON w.id = sm.warehouse_id
         WHERE sm.company_id = v_company
           AND sm.sursa = 'fiscal_receipt'
           AND sm.tip = 'iesire'
           AND w.work_location_id = p_work_location_id
           AND (v_from IS NULL OR sm.created_at > v_from)
           AND (v_to IS NULL OR sm.created_at <= v_to)
         GROUP BY p.id, p.tip, COALESCE(p.cod, ''), p.denumire, COALESCE(NULLIF(sm.unitate_masura, ''), 'buc'),
                  CASE
                      WHEN sm.canal = 'online' AND COALESCE(p.pret_vanzare_online, 0) > 0 THEN p.pret_vanzare_online
                      ELSE COALESCE(p.pret_vanzare, 0)
                  END
    )
    SELECT
        CASE WHEN s.tip = 'garantie' THEN 'Garanție' ELSE COALESCE(g.name, 'Fără grupă') END,
        CASE WHEN s.tip = 'garantie' THEN 90000 ELSE COALESCE(g.sort_order, 100000) END,
        s.cod,
        s.denumire,
        s.um,
        s.cantitate,
        s.pret,
        ROUND(s.cantitate * s.pret, 2)
      FROM sold s
      LEFT JOIN LATERAL (
          SELECT grp.name, grp.sort_order
            FROM public.cm_product_group_members m
            JOIN public.cm_product_groups grp ON grp.id = m.group_id
           WHERE m.product_id = s.product_id
             AND grp.company_id = v_company
             AND grp.kind = 'custom'
           ORDER BY grp.sort_order, grp.name
           LIMIT 1
      ) g ON true
     ORDER BY 2, 1, 4, 3, 7;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_sold_products(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pos_sold_products(uuid, uuid) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
