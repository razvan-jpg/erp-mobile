-- Permite golirea cantității numărate (NULL = stoc neatins la finalizare; 0 = stoc zero).

CREATE OR REPLACE FUNCTION public.clear_physical_inventory_line_count(p_line_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inventory RECORD;
BEGIN
    SELECT i.*
    INTO v_inventory
    FROM public.physical_inventories i
    JOIN public.physical_inventory_lines l ON l.inventory_id = i.id
    WHERE l.id = p_line_id
    FOR UPDATE OF i;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF v_inventory.status <> 'open' THEN
        RAISE EXCEPTION 'INVENTORY_NOT_OPEN';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_inventory.company_id, 'edit'::text, 'edit'::text) THEN
        RAISE EXCEPTION 'INVENTORY_EDIT_FORBIDDEN';
    END IF;

    UPDATE public.physical_inventory_lines
    SET cantitate_numarata = NULL,
        updated_at = now()
    WHERE id = p_line_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.clear_physical_inventory_line_count(UUID) TO authenticated, service_role;
