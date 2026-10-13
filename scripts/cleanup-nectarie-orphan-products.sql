-- Curățare produse Nectarie: păstrăm NIR + catalog CM; orphans → match NIR (denumire
-- normalizată / fuzzy) → mutăm stoc gestiune → ștergem sau is_active=false.
-- NU atinge supplier_invoice_lines / plăți furnizor.
-- Idempotent: rulează doar pe produse active care încă sunt orphan.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO $$
DECLARE
    v_company_id UUID;
    v_company_name TEXT;
    v_orphan_id UUID;
    v_master_id UUID;
    v_orphan_name TEXT;
    v_master_name TEXT;
    v_stock NUMERIC;
    v_matched INT := 0;
    v_deactivated INT := 0;
    v_deleted INT := 0;
    v_skipped_stock INT := 0;
    v_stock_before NUMERIC;
    v_stock_after NUMERIC;
    v_invoice_fp_before TEXT;
    v_invoice_fp_after TEXT;
    v_can_delete BOOLEAN;
BEGIN
    SELECT id, denumire
    INTO v_company_id, v_company_name
    FROM public.companies
    WHERE denumire ILIKE '%nectarie%'
    ORDER BY created_at NULLS LAST
    LIMIT 1;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'Societatea Nectarie nu a fost găsită.';
    END IF;

    RAISE NOTICE 'Cleanup Nectarie: % (%)', v_company_name, v_company_id;

    SELECT COALESCE(SUM(cantitate), 0)
    INTO v_stock_before
    FROM public.product_stocks
    WHERE company_id = v_company_id;

    SELECT md5(string_agg(id::text || ':' || product_id::text, ',' ORDER BY id))
    INTO v_invoice_fp_before
    FROM public.supplier_invoice_lines
    WHERE company_id = v_company_id;

    -- Disable warehouse sync while remapping movements (we merge warehouse stocks manually).
    ALTER TABLE public.stock_movements DISABLE TRIGGER stock_movements_sync_warehouse_stock;

    BEGIN
    FOR v_orphan_id, v_orphan_name, v_stock, v_master_id, v_master_name IN
        WITH norm AS (
            SELECT
                p.id,
                p.denumire,
                p.is_active,
                p.in_catalog,
                upper(trim(both FROM translate(
                    regexp_replace(
                        regexp_replace(
                            regexp_replace(
                                regexp_replace(p.denumire, '\s*\(\s*LOT\s*[^)]*\)\s*$', '', 'i'),
                                '\s+LOT\s+[A-Z0-9./_-]+\s*$', '', 'i'
                            ),
                            '\s*\(\s*\d{6,8}\s*\)\s*$', '', 'i'
                        ),
                        '\s+', ' ', 'g'
                    ),
                    'ĂÂÎȘȚáàâăíîșțşţÁÀĂÂÉÈÍÌÎÓÒÚÙŞŢ',
                    'AAISTAAAIISTSTAAAAEEIIIOOUUSS'
                ))) AS norm_name
            FROM public.products p
            WHERE p.company_id = v_company_id
        ),
        keepers AS (
            SELECT DISTINCT n.id
            FROM norm n
            WHERE n.in_catalog = true
               OR EXISTS (
                    SELECT 1
                    FROM public.supplier_nir_lines snl
                    JOIN public.supplier_nirs sn ON sn.id = snl.nir_id
                    WHERE sn.company_id = v_company_id
                      AND snl.product_id = n.id
               )
               OR EXISTS (
                    SELECT 1 FROM public.cm_product_group_members m
                    WHERE m.company_id = v_company_id AND m.product_id = n.id
               )
               OR EXISTS (
                    SELECT 1
                    FROM public.cm_menu_lines ml
                    JOIN public.cm_menus mm ON mm.id = ml.menu_id
                    WHERE mm.company_id = v_company_id AND ml.product_id = n.id
               )
        ),
        nir_keepers AS (
            SELECT n.id, n.norm_name, n.denumire
            FROM norm n
            WHERE EXISTS (
                SELECT 1
                FROM public.supplier_nir_lines snl
                JOIN public.supplier_nirs sn ON sn.id = snl.nir_id
                WHERE sn.company_id = v_company_id
                  AND snl.product_id = n.id
            )
        ),
        orphans AS (
            SELECT
                n.id,
                n.denumire,
                n.norm_name,
                COALESCE(ps.cantitate, 0) AS stock
            FROM norm n
            LEFT JOIN public.product_stocks ps
                ON ps.product_id = n.id AND ps.company_id = v_company_id
            WHERE n.is_active = true
              AND n.id NOT IN (SELECT id FROM keepers)
        ),
        candidates AS (
            SELECT
                o.id AS orphan_id,
                o.denumire AS orphan_name,
                o.stock,
                nk.id AS master_id,
                nk.denumire AS master_name,
                (o.norm_name = nk.norm_name) AS is_exact,
                (length(o.norm_name) >= 6 AND nk.norm_name LIKE '%' || o.norm_name || '%') AS is_contained,
                similarity(o.norm_name, nk.norm_name) AS sim,
                (o.norm_name IN ('SGR', 'GARANTIE SGR') AND nk.norm_name = 'GARANTIE SGR') AS is_sgr
            FROM orphans o
            JOIN nir_keepers nk ON (
                o.norm_name = nk.norm_name
                OR similarity(o.norm_name, nk.norm_name) >= 0.55
                OR (length(o.norm_name) >= 6 AND nk.norm_name LIKE '%' || o.norm_name || '%')
                OR (o.norm_name IN ('SGR', 'GARANTIE SGR') AND nk.norm_name = 'GARANTIE SGR')
            )
        ),
        ranked AS (
            SELECT
                *,
                row_number() OVER (
                    PARTITION BY orphan_id
                    ORDER BY is_sgr DESC, is_exact DESC, is_contained DESC, sim DESC, master_name
                ) AS rn
            FROM candidates
        )
        SELECT orphan_id, orphan_name, stock, master_id, master_name
        FROM ranked
        WHERE rn = 1
    LOOP
        RAISE NOTICE 'Match: "%" (%) → "%" (%) stock=%',
            v_orphan_name, v_orphan_id, v_master_name, v_master_id, v_stock;

        -- Company stock
        UPDATE public.product_stocks m
        SET cantitate = m.cantitate + d.cantitate,
            updated_at = now()
        FROM public.product_stocks d
        WHERE d.product_id = v_orphan_id
          AND d.company_id = v_company_id
          AND m.product_id = v_master_id
          AND m.company_id = v_company_id;

        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        SELECT d.company_id, v_master_id, d.cantitate
        FROM public.product_stocks d
        WHERE d.product_id = v_orphan_id
          AND d.company_id = v_company_id
          AND NOT EXISTS (
              SELECT 1 FROM public.product_stocks m
              WHERE m.company_id = d.company_id AND m.product_id = v_master_id
          );

        DELETE FROM public.product_stocks
        WHERE product_id = v_orphan_id AND company_id = v_company_id;

        -- Warehouse stock
        UPDATE public.warehouse_product_stocks w
        SET cantitate = w.cantitate + d.cantitate,
            updated_at = now()
        FROM public.warehouse_product_stocks d
        WHERE d.product_id = v_orphan_id
          AND d.company_id = v_company_id
          AND w.product_id = v_master_id
          AND w.company_id = d.company_id
          AND w.warehouse_id = d.warehouse_id;

        INSERT INTO public.warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
        SELECT d.company_id, d.warehouse_id, v_master_id, d.cantitate
        FROM public.warehouse_product_stocks d
        WHERE d.product_id = v_orphan_id
          AND d.company_id = v_company_id
          AND NOT EXISTS (
              SELECT 1 FROM public.warehouse_product_stocks w
              WHERE w.company_id = d.company_id
                AND w.warehouse_id = d.warehouse_id
                AND w.product_id = v_master_id
          );

        DELETE FROM public.warehouse_product_stocks
        WHERE product_id = v_orphan_id AND company_id = v_company_id;

        -- Gestiune FKs (NOT supplier_invoice_lines)
        UPDATE public.stock_movements
        SET product_id = v_master_id
        WHERE product_id = v_orphan_id AND company_id = v_company_id;

        UPDATE public.stock_transfer_lines
        SET product_id = v_master_id
        WHERE product_id = v_orphan_id AND company_id = v_company_id;

        UPDATE public.physical_inventory_lines
        SET product_id = v_master_id
        WHERE product_id = v_orphan_id AND company_id = v_company_id;

        UPDATE public.inventory_difference_report_lines
        SET product_id = v_master_id
        WHERE product_id = v_orphan_id AND company_id = v_company_id;

        UPDATE public.product_recipe_lines
        SET product_id = v_master_id
        WHERE product_id = v_orphan_id;

        UPDATE public.product_recipe_lines
        SET ingredient_product_id = v_master_id
        WHERE ingredient_product_id = v_orphan_id;

        UPDATE public.company_fiscal_sale_receipt_lines
        SET product_id = v_master_id
        WHERE product_id = v_orphan_id AND company_id = v_company_id;

        UPDATE public.crm_deal_products
        SET product_id = v_master_id
        WHERE product_id = v_orphan_id;

        UPDATE public.crm_quote_lines
        SET product_id = v_master_id
        WHERE product_id = v_orphan_id;

        -- Sale addons: drop self-links / conflicts, then re-point
        DELETE FROM public.product_sale_addons
        WHERE company_id = v_company_id
          AND (
              (product_id = v_orphan_id AND addon_product_id = v_master_id)
              OR (product_id = v_master_id AND addon_product_id = v_orphan_id)
              OR (product_id = v_orphan_id AND addon_product_id = v_orphan_id)
          );

        UPDATE public.product_sale_addons
        SET product_id = v_master_id
        WHERE product_id = v_orphan_id AND company_id = v_company_id
          AND NOT EXISTS (
              SELECT 1 FROM public.product_sale_addons x
              WHERE x.company_id = v_company_id
                AND x.product_id = v_master_id
                AND x.addon_product_id = product_sale_addons.addon_product_id
          );

        DELETE FROM public.product_sale_addons
        WHERE product_id = v_orphan_id AND company_id = v_company_id;

        UPDATE public.product_sale_addons
        SET addon_product_id = v_master_id
        WHERE addon_product_id = v_orphan_id AND company_id = v_company_id
          AND NOT EXISTS (
              SELECT 1 FROM public.product_sale_addons x
              WHERE x.company_id = v_company_id
                AND x.product_id = product_sale_addons.product_id
                AND x.addon_product_id = v_master_id
          );

        DELETE FROM public.product_sale_addons
        WHERE addon_product_id = v_orphan_id AND company_id = v_company_id;

        v_matched := v_matched + 1;

        -- Delete if safe; else deactivate (invoice RESTRICT remains)
        SELECT NOT EXISTS (
            SELECT 1 FROM public.supplier_invoice_lines WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.stock_movements WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.stock_transfer_lines WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.physical_inventory_lines WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.product_recipe_lines
            WHERE product_id = v_orphan_id OR ingredient_product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.product_sale_addons
            WHERE product_id = v_orphan_id OR addon_product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.cm_menu_lines WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.cm_product_group_members WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.supplier_nir_lines WHERE product_id = v_orphan_id
        )
        INTO v_can_delete;

        IF v_can_delete THEN
            DELETE FROM public.products WHERE id = v_orphan_id AND company_id = v_company_id;
            v_deleted := v_deleted + 1;
        ELSE
            UPDATE public.products
            SET is_active = false, updated_at = now()
            WHERE id = v_orphan_id AND company_id = v_company_id;
            v_deactivated := v_deactivated + 1;
        END IF;
    END LOOP;

    -- Unmatched orphans: deactivate (or delete if no FKs). Skip stock merge.
    -- Unmatched with nonzero stock: deactivate only + NOTICE (plan: report/skip merge).
    FOR v_orphan_id, v_orphan_name, v_stock IN
        WITH norm AS (
            SELECT
                p.id,
                p.denumire,
                p.is_active,
                p.in_catalog,
                upper(trim(both FROM translate(
                    regexp_replace(
                        regexp_replace(
                            regexp_replace(
                                regexp_replace(p.denumire, '\s*\(\s*LOT\s*[^)]*\)\s*$', '', 'i'),
                                '\s+LOT\s+[A-Z0-9./_-]+\s*$', '', 'i'
                            ),
                            '\s*\(\s*\d{6,8}\s*\)\s*$', '', 'i'
                        ),
                        '\s+', ' ', 'g'
                    ),
                    'ĂÂÎȘȚáàâăíîșțşţÁÀĂÂÉÈÍÌÎÓÒÚÙŞŢ',
                    'AAISTAAAIISTSTAAAAEEIIIOOUUSS'
                ))) AS norm_name
            FROM public.products p
            WHERE p.company_id = v_company_id
        ),
        keepers AS (
            SELECT DISTINCT n.id
            FROM norm n
            WHERE n.in_catalog = true
               OR EXISTS (
                    SELECT 1
                    FROM public.supplier_nir_lines snl
                    JOIN public.supplier_nirs sn ON sn.id = snl.nir_id
                    WHERE sn.company_id = v_company_id AND snl.product_id = n.id
               )
               OR EXISTS (
                    SELECT 1 FROM public.cm_product_group_members m
                    WHERE m.company_id = v_company_id AND m.product_id = n.id
               )
               OR EXISTS (
                    SELECT 1
                    FROM public.cm_menu_lines ml
                    JOIN public.cm_menus mm ON mm.id = ml.menu_id
                    WHERE mm.company_id = v_company_id AND ml.product_id = n.id
               )
        ),
        nir_keepers AS (
            SELECT n.id, n.norm_name, n.denumire
            FROM norm n
            WHERE EXISTS (
                SELECT 1
                FROM public.supplier_nir_lines snl
                JOIN public.supplier_nirs sn ON sn.id = snl.nir_id
                WHERE sn.company_id = v_company_id AND snl.product_id = n.id
            )
        ),
        orphans AS (
            SELECT
                n.id,
                n.denumire,
                n.norm_name,
                COALESCE(ps.cantitate, 0) AS stock
            FROM norm n
            LEFT JOIN public.product_stocks ps
                ON ps.product_id = n.id AND ps.company_id = v_company_id
            WHERE n.is_active = true
              AND n.id NOT IN (SELECT id FROM keepers)
        )
        SELECT o.id, o.denumire, o.stock
        FROM orphans o
        WHERE NOT EXISTS (
            SELECT 1
            FROM nir_keepers nk
            WHERE o.norm_name = nk.norm_name
               OR similarity(o.norm_name, nk.norm_name) >= 0.55
               OR (length(o.norm_name) >= 6 AND nk.norm_name LIKE '%' || o.norm_name || '%')
               OR (o.norm_name IN ('SGR', 'GARANTIE SGR') AND nk.norm_name = 'GARANTIE SGR')
        )
    LOOP
        IF v_stock <> 0 THEN
            RAISE NOTICE 'Skip merge (unmatched with stock): "%" (%) stock=% — deactivate only',
                v_orphan_name, v_orphan_id, v_stock;
            v_skipped_stock := v_skipped_stock + 1;
            UPDATE public.products
            SET is_active = false, updated_at = now()
            WHERE id = v_orphan_id AND company_id = v_company_id;
            v_deactivated := v_deactivated + 1;
            CONTINUE;
        END IF;

        SELECT NOT EXISTS (
            SELECT 1 FROM public.supplier_invoice_lines WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.stock_movements WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.stock_transfer_lines WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.physical_inventory_lines WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.product_recipe_lines
            WHERE product_id = v_orphan_id OR ingredient_product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.product_sale_addons
            WHERE product_id = v_orphan_id OR addon_product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.product_stocks WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.warehouse_product_stocks WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.cm_menu_lines WHERE product_id = v_orphan_id
        ) AND NOT EXISTS (
            SELECT 1 FROM public.cm_product_group_members WHERE product_id = v_orphan_id
        )
        INTO v_can_delete;

        IF v_can_delete THEN
            DELETE FROM public.products WHERE id = v_orphan_id AND company_id = v_company_id;
            v_deleted := v_deleted + 1;
        ELSE
            UPDATE public.products
            SET is_active = false, updated_at = now()
            WHERE id = v_orphan_id AND company_id = v_company_id;
            v_deactivated := v_deactivated + 1;
        END IF;
    END LOOP;

    EXCEPTION WHEN OTHERS THEN
        ALTER TABLE public.stock_movements ENABLE TRIGGER stock_movements_sync_warehouse_stock;
        RAISE;
    END;

    ALTER TABLE public.stock_movements ENABLE TRIGGER stock_movements_sync_warehouse_stock;

    SELECT COALESCE(SUM(cantitate), 0)
    INTO v_stock_after
    FROM public.product_stocks
    WHERE company_id = v_company_id;

    SELECT md5(string_agg(id::text || ':' || product_id::text, ',' ORDER BY id))
    INTO v_invoice_fp_after
    FROM public.supplier_invoice_lines
    WHERE company_id = v_company_id;

    IF v_invoice_fp_before IS DISTINCT FROM v_invoice_fp_after THEN
        RAISE EXCEPTION 'ABORT: supplier_invoice_lines fingerprint changed (facturi atinse).';
    END IF;

    -- Stock total should be unchanged for matched merges; CONSUM* stock stays on deactivated products.
    IF v_stock_before IS DISTINCT FROM v_stock_after THEN
        RAISE NOTICE 'Stock total changed: before=% after=% (expected only if deactivated orphans still hold stock)',
            v_stock_before, v_stock_after;
    END IF;

    RAISE NOTICE 'Done. matched=% deleted=% deactivated=% unmatched_with_stock_skipped_merge=% active_now=% stock_before=% stock_after=%',
        v_matched, v_deleted, v_deactivated, v_skipped_stock,
        (SELECT count(*) FROM public.products WHERE company_id = v_company_id AND is_active),
        v_stock_before, v_stock_after;
END $$;
