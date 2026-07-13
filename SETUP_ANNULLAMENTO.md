# Setup annullamento prenotazioni (cliente)

Il cliente ora può annullare una prenotazione **anche dopo la conferma**,
fino a **2 ore prima** dell'appuntamento. La regola è applicata lato server
(RPC `cancel_own_booking`), quindi non è aggirabile.

Quando un cliente annulla:
- il barbiere vede l'annullamento nella **dashboard** (sezione "Annullate dai clienti") e il calendario si aggiorna in tempo reale;
- il barbiere riceve una **notifica Telegram**;
- il cliente riceve una **email di conferma annullamento**.

Per attivare tutto servono questi passaggi.

---

## 1. Patch database (obbligatorio)

Supabase → **SQL Editor** → incolla ed esegui tutto il contenuto di
[`patch_client_cancel.sql`](patch_client_cancel.sql).

Aggiunge le colonne `cancelled_at` / `cancelled_by` alle prenotazioni,
`telegram_chat_id` allo staff, crea la RPC `cancel_own_booking` con la
regola delle 2 ore e rimuove la vecchia policy.

> ⚠️ Esegui la patch **prima** di mettere online il nuovo `index.html`:
> il pulsante "Annulla" del frontend aggiornato usa la RPC.

---

## 2. Notifica Telegram al barbiere

Si usa il **bot Telegram già esistente**: non serve crearne uno nuovo.

1. **Recupera il token del bot**: è quello che usi già (formato
   `123456:ABC-...`). Se non lo ritrovi, su **@BotFather** →
   `/mybots` → seleziona il bot → **API Token**.
2. **Verifica che i barbieri abbiano avviato il bot**: se il bot scrive
   già ad Antonio e Giuseppe è tutto ok; altrimenti devono cercarlo su
   Telegram e premere **Avvia** (`/start`), altrimenti il bot non può
   scrivergli (limite di Telegram).
3. **Recupera il chat_id di ciascuno**: se il bot già gli scrive, il
   chat_id ce l'hai già dove gestisci gli invii. In alternativa:
   - ogni barbiere scrive a **@userinfobot**, che risponde con il
     proprio `Id` (un numero, es. `123456789`);
   - oppure, dopo che il barbiere ha scritto al bot, apri
     `https://api.telegram.org/bot<TOKEN>/getUpdates` e leggi
     `message.chat.id`.
4. **Inserisci i chat_id nell'app**: account admin → **Team** →
   profilo del barbiere → campo **"Telegram Chat ID"** → salva.
   Senza chat_id la notifica Telegram per quel barbiere non parte
   (l'email al cliente parte comunque).

---

## 3. Email al cliente: account Resend

La conferma di annullamento al cliente parte via email tramite
[Resend](https://resend.com) (3.000 email/mese gratuite).

1. Crea un account su **resend.com**.
2. **Domains → Add Domain** → `hairstudiosbarbershop.com` → aggiungi i
   record DNS che ti mostra (SPF + DKIM) dal pannello del tuo dominio →
   attendi la verifica (di solito pochi minuti).
   - *In alternativa, per provare subito senza verificare il dominio,
     puoi saltare questo punto: le email partiranno da
     `onboarding@resend.dev`, ma solo verso l'indirizzo con cui ti sei
     registrato su Resend. Per l'uso reale il dominio va verificato.*
3. **API Keys → Create API Key** → copia la chiave (`re_...`).

---

## 4. Edge Function su Supabase

1. Dashboard Supabase → **Edge Functions → Deploy a new function →
   Via Editor** → nome: `booking-cancelled`.
2. Incolla il contenuto di
   [`supabase/functions/booking-cancelled/index.ts`](supabase/functions/booking-cancelled/index.ts)
   e fai **Deploy**.
3. **Edge Functions → Secrets** → aggiungi:
   | Nome | Valore |
   |---|---|
   | `TELEGRAM_BOT_TOKEN` | il token del bot esistente (punto 2.1) |
   | `RESEND_API_KEY` | la chiave `re_...` (punto 3.3) |
   | `MAIL_FROM` | `Hair Studios <prenotazioni@hairstudiosbarbershop.com>` |

   (se non hai ancora verificato il dominio su Resend, ometti `MAIL_FROM`:
   verrà usato il mittente di prova di Resend)

> In alternativa, con la CLI Supabase:
> `supabase functions deploy booking-cancelled` +
> `supabase secrets set TELEGRAM_BOT_TOKEN=... RESEND_API_KEY=re_... MAIL_FROM="Hair Studios <prenotazioni@hairstudiosbarbershop.com>"`

---

## Verifica finale

1. Metti online il nuovo `index.html` + `sw.js`.
2. Da un account cliente: prenota, fatti confermare la prenotazione,
   poi annullala da "Le mie prenotazioni" (doppia conferma "Sì, annulla").
3. Controlla: toast "Prenotazione annullata", sezione "Annullate dai
   clienti" nella dashboard admin, messaggio Telegram al barbiere
   ed email di conferma al cliente.
4. Prova con un appuntamento a meno di 2 ore: il pulsante non compare
   e compare "Annullabile fino a 2h prima".
