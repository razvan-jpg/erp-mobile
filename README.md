# ERP Mobile — Dateconta

Aplicație iOS SwiftUI pentru ERP, conectată la **Supabase** (PostgreSQL + Auth). Include autentificare, utilizator Admin implicit și management complet al utilizatorilor cu drepturi pe module extensibile.

## Cerințe

- Xcode 26+
- Cont [Supabase](https://supabase.com)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (opțional, pentru deploy local)

## Setup Supabase (automat — recomandat)

Dacă nu ai cont Supabase, scriptul te ghidează pas cu pas.

### Varianta 1: dublu-click (cel mai simplu)

1. Deschide **`SETUP-SUPABASE.command`** (dublu-click în Finder)
2. Se deschide browserul — creează cont gratuit pe [supabase.com](https://supabase.com) dacă nu ai
3. Confirmă autentificarea în browser
4. Scriptul creează automat: proiect cloud, migrări, Edge Functions, `Secrets.xcconfig`

### Varianta 2: terminal

```bash
cd "ERP Mobile"
./scripts/supabase-setup.sh
```

Scriptul execută echivalentul:
- `supabase login`
- `supabase projects create`
- `supabase link`
- `supabase db push`
- `supabase functions deploy` (toate funcțiile admin)

## Setup iOS

### 1. Deschideți și rulați

1. Deschideți `ERP Mobile.xcodeproj`
2. Așteptați rezolvarea pachetului `supabase-swift`
3. Rulați pe simulator sau dispozitiv

La primul launch, aplicația invocă `seed-admin` și creează utilizatorul **Superadmin** (idempotent — nu dublează contul dacă există deja).

## Confirmare email la creare utilizator

La crearea unui utilizator nou, contul rămâne **inactiv** până când utilizatorul confirmă adresa de email. Autentificarea în app este blocată până la confirmare.

### Configurare Supabase Auth

În **Supabase Dashboard → Authentication → Providers → Email**, activați **Confirm email**.

### Emailuri (Resend)

Configurați în **Edge Functions → Secrets** (sau rulați `CONFIGURE-RESEND.command`):

- `RESEND_API_KEY` — cheia API de la [resend.com](https://resend.com)
- `EMAIL_FROM` — ex. `ERP Mobile <ERPMobile@dateconta.ro>`
- `EMAIL_CONFIRM_REDIRECT_URL` — pagina după confirmare: `https://rincon.ro/email-confirmat.html`
- `ACTIVATION_EMAIL_CC` — CC la emailul cu date cont după confirmare (implicit: `ERPMobile@dateconta.ro`)

**Resend — domeniu obligatoriu:** adresa `ERPMobile@dateconta.ro` funcționează doar dacă **`dateconta.ro` este Verified** în Resend → Domains. Adăugați recordurile DNS în cPanel → Zone Editor, apoi **Verify** în Resend.

### Pagină confirmare email (rincon.ro)

**Supabase nu poate servi pagini HTML** (Edge Functions și Storage returnează text simplu, nu pagină web).

1. Rulați **`UPLOAD-EMAIL-PAGE.command`** (generează `web/email-confirmat.built.html`)
2. Încărcați fișierul pe hosting-ul **rincon.ro** ca `email-confirmat.html`
3. Verificați: [https://rincon.ro/email-confirmat.html](https://rincon.ro/email-confirmat.html) — trebuie să arate ca pagină web, nu ca cod sursă

În **Authentication → URL Configuration → Redirect URLs**, adăugați același URL de confirmare.

**Flux:**
1. Utilizatorul primește email cu link de confirmare
2. După click → pagină: *„Contul a fost confirmat cu succes. Vă puteți autentifica în aplicație”*
3. Utilizatorul primește automat email cu datele contului (parolă, module); **CC** la `ERPMobile@dateconta.ro` (+ administratorul care a creat contul, dacă e alt email)

## Superadmin (cont global)

| Câmp | Valoare |
|------|---------|
| Email | `razvan.ivan@icloud.com` |
| Parolă | `David12!` |

Contul superadmin este creat automat la launch, **nu poate fi șters** din baza de date și are drepturi de administrare globale.

## Roluri și drepturi

| Rol | Cine | Ce poate face |
|-----|------|----------------|
| **Superadmin** | `razvan.ivan@icloud.com` | Creează societăți (ANAF), alocă drepturi pe societăți, gestionează toți utilizatorii |
| **Admin societate** | creat la fiecare societate nouă | Administrare doar în societatea unde a fost creat: utilizatori, module, date furnizori |
| **Utilizator** | creat de superadmin sau admin societate | Acces conform drepturilor pe module și societate |

### Flux recomandat

1. Autentificare superadmin → tab **Setări** → **Adaugă societate** (date ANAF + administrator societate)
2. Administratorul societății confirmă emailul și lucrează doar în societatea sa
3. Superadminul poate aloca utilizatori obișnuiți pe una sau mai multe societăți

## Funcționalități administrare

- Creare utilizatori (Nume, Prenume, CNP, email, telefon, drepturi)
- Editare date și parolă
- Atribuire drepturi pe module (`can_view`, `can_create`, `can_edit`, `can_delete`)
- Atribuire drepturi pe societăți (doar superadmin)
- Blocare / deblocare cont
- Ștergere permanentă (superadmin și adminii de societate sunt protejați)

## Module disponibile

| Cod | Nume |
|-----|------|
| `supplier_invoices_payments` | Furnizori |

Modulele sunt definite în migrările SQL (`supabase/migrations/`). Apare automat în aplicație; Admin poate atribui drepturi utilizatorilor.

## Adăugare module noi

Adăugați o migrare SQL sau inserați în tabelul `modules`:

```sql
INSERT INTO modules (code, name, description, sort_order)
VALUES ('cod_modul', 'Nume modul', 'Descriere', 20);
```

Pentru ecran dedicat în app, adăugați codul în `ModuleCode.swift` și ruta în `ModuleDestinationView.swift`.

## Structură proiect

```
ERP Mobile/          — aplicație iOS SwiftUI
supabase/
  migrations/        — schema PostgreSQL + RLS
  functions/       — Edge Functions (management utilizatori)
```

## Securitate

- Cheia `service_role` rămâne doar pe server (Edge Functions)
- `Secrets.xcconfig` este exclus din git
- RLS activ pe toate tabelele publice
