# Setup notifiche push

Notifiche push web per **clienti** e **barbieri**, su Android (browser + app TWA)
e iPhone (PWA aggiunta alla Home, iOS 16.4+).

Eventi gestiti:
| Evento | Destinatario |
|---|---|
| Nuova prenotazione da confermare | Barbiere |
| Prenotazione annullata dal cliente | Barbiere |
| Prenotazione confermata | Cliente |
| Appuntamento spostato | Cliente |
| Prenotazione annullata/rifiutata dal barbiere | Cliente |
| Promemoria appuntamento (Fase 2) | Cliente |

---

## 1. Patch database

Supabase → **SQL Editor** → esegui la **prima parte** di
[`patch_push.sql`](patch_push.sql) (fino a "FASE 2"): crea la tabella
`push_subscriptions` e la colonna `reminder_sent`.
La Fase 2 (promemoria) si fa dopo, quando le notifiche evento funzionano.

## 2. Edge Function `send-push`

1. Dashboard → **Edge Functions → Deploy a new function → Via Editor** →
   nome: `send-push`.
2. Incolla il contenuto di
   [`supabase/functions/send-push/index.ts`](supabase/functions/send-push/index.ts)
   → **Deploy**.
3. **Edge Functions → Secrets** → aggiungi:
   | Nome | Valore |
   |---|---|
   | `VAPID_PUBLIC_KEY` | `BFgyuGerCg0mB8L9QbHQUFFhBr2BCRbIO2RTpLHqf3qbGHccrRNEGR3tE-cTu8aZI7bpEtNIkhTb0kLWjxBGEHU` |
   | `VAPID_PRIVATE_KEY` | *(fornita a parte in chat — NON è nel repo)* |
   | `VAPID_SUBJECT` | `mailto:info@hairstudiosbarbershop.com` (o una tua email) |

> La chiave pubblica è già inserita nel frontend (`index.html`). Le due chiavi
> devono essere la **stessa coppia**: se un giorno le rigeneri, vanno cambiate
> in entrambi i posti.

## 3. App Android (TWA) — rigenerare con notifiche attive

La TWA sul Play Store riceve le push solo se generata con la
**delega delle notifiche** attiva. Poiché sei ancora in test:

1. Su **pwabuilder.com** → analizza il sito → **Package For Stores → Android**
2. Nelle opzioni **attiva "Include notification delegation"** (o "Enable
   notifications")
3. ⚠️ **Usa la stessa chiave di firma** (`signing.keystore`) e lo stesso
   package `com.hairstudiosbarbershop.twa` — NON generarne una nuova
4. Carica il nuovo `.aab` nel canale di **test interno**

## 4. iPhone — installazione sulla Home

Su iOS le push arrivano **solo dalla PWA aggiunta alla schermata Home**
(iOS 16.4+). Il cliente: Safari → **Condividi** → **Aggiungi a Home**, apre
l'app da lì, poi va in **Profilo → Attiva le notifiche**. L'app mostra già
questo avviso agli utenti iPhone non installati.

## 5. Come si attivano (lato utente)

Nell'app: **Profilo → 🔔 Attiva le notifiche** → consenti. Da quel momento
il dispositivo è iscritto. Lo stesso vale per i barbieri dal profilo Admin.

---

## FASE 2 · Promemoria automatici (facoltativa, dopo)

Invia un promemoria per gli appuntamenti confermati entro le 24 ore successive.

1. Supabase → **Database → Extensions** → abilita **`pg_cron`** e **`pg_net`**
2. Nel SQL Editor esegui la **Fase 2** di `patch_push.sql`, sostituendo:
   - `<PROJECT_REF>` → il ref del progetto (es. `pzdnvygxnosmxrjfjvsv`)
   - `<SERVICE_ROLE_KEY>` → Project Settings → API → `service_role` key
3. Il job gira ogni ora e invia i promemoria dovuti (una sola volta per
   prenotazione, grazie a `reminder_sent`).

---

## Verifica

1. Metti online il nuovo frontend + `sw.js`
2. Da un iPhone/Android installato: **Profilo → Attiva le notifiche** → consenti
3. Prenota da un account cliente → il **barbiere** riceve "Nuova prenotazione"
4. Il barbiere conferma → il **cliente** riceve "Prenotazione confermata"
5. Se non arriva nulla: controlla i log della Edge Function (Dashboard →
   Edge Functions → send-push → Logs) e che i secret VAPID siano impostati.
