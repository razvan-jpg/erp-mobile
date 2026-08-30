#!/usr/bin/env python3
"""Golește datele operaționale ale unei societăți via Supabase REST."""
from __future__ import annotations

import json
import os
import plistlib
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLIST = ROOT / "ERP Mobile/Config/SupabaseSecrets.plist"
ADMIN_EMAIL = os.environ.get("ERP_ADMIN_EMAIL", "razvan.ivan@icloud.com")
ADMIN_PASSWORD = os.environ.get("ERP_ADMIN_PASSWORD", "David12!")

TABLES = [
    "supplier_nir_lines",
    "supplier_nir_released_numbers",
    "supplier_nirs",
    "stock_movements",
    "physical_inventory_lines",
    "physical_inventories",
    "supplier_payments",
    "supplier_invoice_credit_offsets",
    "supplier_invoice_lines",
    "supplier_invoices",
    "product_recipe_lines",
    "product_stocks",
    "products",
    "suppliers",
    "client_payments",
    "client_invoices",
    "clients",
    "company_warehouses",
    "company_work_locations",
]

CHECK_TABLES = ["suppliers", "products", "supplier_invoices", "product_stocks", "stock_movements"]


def load_config() -> tuple[str, str]:
    with PLIST.open("rb") as handle:
        data = plistlib.load(handle)
    return data["SUPABASE_URL"].rstrip("/"), data["SUPABASE_ANON_KEY"]


class SupabaseClient:
    def __init__(self, base_url: str, anon_key: str) -> None:
        self.base_url = base_url
        self.anon_key = anon_key
        req = urllib.request.Request(
            f"{base_url}/auth/v1/token?grant_type=password",
            data=json.dumps({"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD}).encode(),
            headers={"apikey": anon_key, "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            auth = json.load(resp)
        self.token = auth["access_token"]
        self.user_id = auth["user"]["id"]

    def _headers(self, prefer: str = "return=minimal,count=exact") -> dict[str, str]:
        return {
            "apikey": self.anon_key,
            "Authorization": f"Bearer {self.token}",
            "Prefer": prefer,
        }

    def get_json(self, path: str) -> list[dict]:
        req = urllib.request.Request(f"{self.base_url}{path}", headers=self._headers("return=representation"))
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.load(resp)

    def request(self, method: str, path: str, payload: dict | None = None) -> tuple[int, str, str]:
        body = None if payload is None else json.dumps(payload).encode()
        req = urllib.request.Request(
            f"{self.base_url}{path}",
            data=body,
            headers=self._headers(),
            method=method,
        )
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                return resp.status, resp.headers.get("Content-Range", ""), ""
        except urllib.error.HTTPError as exc:
            return exc.code, "", exc.read().decode()

    def find_company(self, search: str) -> tuple[str, str]:
        query = (
            "/rest/v1/companies?select=id,denumire"
            f"&denumire=ilike.*{search}*&order=created_at.desc&limit=1"
        )
        rows = self.get_json(query)
        if not rows:
            raise RuntimeError(f"Societatea '{search}' nu a fost găsită.")
        return rows[0]["id"], rows[0]["denumire"]

    def ensure_selected_company(self, company_id: str) -> None:
        profile = self.get_json(f"/rest/v1/user_profiles?id=eq.{self.user_id}&select=selected_company_id")[0]
        if profile.get("selected_company_id") == company_id:
            return
        status, _, err = self.request(
            "PATCH",
            f"/rest/v1/user_profiles?id=eq.{self.user_id}",
            {"selected_company_id": company_id},
        )
        if status >= 400:
            raise RuntimeError(
                "Selectează societatea în aplicație, apoi reîncearcă. "
                f"Nu am putut seta selected_company_id ({err})."
            )

    def count_rows(self, table: str, company_id: str) -> str:
        status, content_range, err = self.request(
            "GET",
            f"/rest/v1/{table}?select=company_id&company_id=eq.{company_id}&limit=1",
        )
        if status >= 400:
            return f"err:{status}"
        return content_range.split("/")[-1] if "/" in content_range else "0"

    def wipe_company(self, company_id: str) -> None:
        self.ensure_selected_company(company_id)
        for table in TABLES:
            status, content_range, err = self.request("DELETE", f"/rest/v1/{table}?company_id=eq.{company_id}")
            if status >= 400:
                if "PGRST205" in err or "Could not find the table" in err:
                    print(f"  {table}: omis (tabel inexistent)")
                    continue
                raise RuntimeError(f"Eroare la {table} ({status}): {err[:400]}")
            deleted = content_range.split("/")[-1] if "/" in content_range else "0"
            print(f"  {table}: {deleted} rânduri")


def main() -> int:
    search = sys.argv[1] if len(sys.argv) > 1 else "bunatati*maria"
    if not PLIST.exists():
        print("Lipsește SupabaseSecrets.plist", file=sys.stderr)
        return 1

    base_url, anon_key = load_config()
    client = SupabaseClient(base_url, anon_key)
    company_id, company_name = client.find_company(search)

    print(f"Golire: {company_name} ({company_id})")
    print("Înainte:", {table: client.count_rows(table, company_id) for table in CHECK_TABLES})
    client.wipe_company(company_id)
    print("După:", {table: client.count_rows(table, company_id) for table in CHECK_TABLES})
    print("Golire finalizată.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
