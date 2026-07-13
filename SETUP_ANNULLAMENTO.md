# Setup annullamento prenotazioni (cliente)

Il cliente ora può annullare una prenotazione **anche dopo la conferma**,
fino a **2 ore prima** dell'appuntamento. La regola è applicata lato server
(RPC `cancel_own_booking`), quindi non è aggirabile.

Quando un cliente annulla:
- il barbiere vede l'annullamento nella **dashboard** (sezione "Annullate dai clienti") e il calendario si aggiorna in tempo reale;
- il barbiere riceve una **email di notifica**;
- il cliente riceve una **email di conferma annullamento**.

Per attivare tutto servono 3 passaggi.

---

## 1. Patch database (obbligatorio)

Supabase → **SQL Editor** → incolla ed esegui tutto il contenuto di
[`patch_client_cancel.sql`](patch_client_cancel.sql).

Aggiunge le colonne `cancelled_at` / `cancelled_by`, crea la RPC
`cancel_own_booking` con la regola delle 2 ore e rimuove la vecchia policy.

> ⚠️ Esegui la patch **prima** di mettere online il nuovo `index.html`:
> il pulsante "Annulla" del frontend aggiornato usa la RPC.

---

## 2. Email: account Resend (per notifica barbiere + conferma cliente)

Le email partono da una Edge Function tramite [Resend](https://resend.com)
(3.000 email/mese gratuite, più che sufficienti).

1. Crea un account su **resend.com**.
2. **Domains → Add Domain** → `hairstudiosbarbershop.com` → aggiungi i
   record DNS che ti mostra (SPF + DKIM) dal pannello del tuo dominio →
   attendi la verifica (di solito pochi minuti).
   - *In alternativa, per provare subito senza verificare il dominio,
     puoi saltare questo punto: le email partiranno da
     `onboarding@resend.dev`, ma solo verso l'indirizzo con cui ti sei
     registrato su Resend. Per l'uso reale il dominio va verificato.*
3. **API Keys → Create API Key** → copia la chiave (`re_...`).

## 3. Edge Function su Supabase

1. Dashboard Supabase → **Edge Functions → Deploy a new function →
   Via Editor** → nome: `booking-cancelled`.
2. Incolla il contenuto di
   [`supabase/functions/booking-cancelled/index.ts`](supabase/functions/booking-cancelled/index.ts)
   e fai **Deploy**.
3. **Edge Functions → Secrets** → aggiungi:
   | Nome | Valore |
   |---|---|
   | `RESEND_API_KEY` | la chiave `re_...` del punto 2 |
   | `MAIL_FROM` | `Hair Studios <prenotazioni@hairstudiosbarbershop.com>` |

   (se non hai ancora verificato il dominio, ometti `MAIL_FROM`:
   verrà usato il mittente di prova di Resend)

> In alternativa, con la CLI Supabase:
> `supabase functions deploy booking-cancelled` +
> `supabase secrets set RESEND_API_KEY=re_... MAIL_FROM="Hair Studios <prenotazioni@hairstudiosbarbershop.com>"`

---

## 4. Email dei barbieri nell'app

La notifica al barbiere viene inviata all'indirizzo salvato nel suo
profilo staff: app → account admin → **Team** → profilo del barbiere →
campo **Email**. Controlla che sia compilato per Antonio e Giuseppe,
altrimenti la notifica al barbiere non parte (quella al cliente sì).

---

## Verifica finale

1. Metti online il nuovo `index.html` + `sw.js`.
2. Da un account cliente: prenota, fatti confermare la prenotazione,
   poi annullala da "Le mie prenotazioni" (doppia conferma "Sì, annulla").
3. Controlla: toast "Prenotazione annullata", sezione "Annullate dai
   clienti" nella dashboard admin, email al barbiere ed email al cliente.
4. Prova con un appuntamento a meno di 2 ore: il pulsante non compare
   e compare "Annullabile fino a 2h prima".
