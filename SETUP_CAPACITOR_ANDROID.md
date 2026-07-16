# App Android nativa con Capacitor — Guida (Windows)

Passiamo dalla TWA a un'app **Capacitor** che carica il sito live e usa le
**notifiche push native (FCM)** — affidabili su ogni Android, anche Xiaomi.
Il sito web non cambia: continui ad aggiornarlo su Netlify come ora.

Procediamo per **3 tappe**. Facciamo la Tappa 1, poi passiamo alle altre.

---

## TAPPA 1 · Far girare l'app sul telefono

### 1.1 Prerequisiti (una volta sola)
1. **Node.js LTS** → [nodejs.org](https://nodejs.org) → installa la versione "LTS".
2. **Android Studio** → [developer.android.com/studio](https://developer.android.com/studio) →
   installa, aprilo una volta e completa il setup (scarica l'SDK quando lo chiede).
3. **Telefono in modalità sviluppatore**:
   - Impostazioni → Info telefono → tocca 7 volte "Numero build"
   - Impostazioni → Opzioni sviluppatore → attiva **Debug USB**
   - Collega il telefono al PC via USB e autorizza la connessione

> ⚠️ Se PowerShell blocca `npm`/`npx` con "esecuzione di script disabilitata",
> lancia una volta: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
> (rispondi `S`), oppure usa `npm.cmd` / `npx.cmd`.

### 1.2 Installa Capacitor
Apri il terminale nella cartella `native` del progetto:
```
cd native
npm install
```

### 1.3 Aggiungi la piattaforma Android
```
npx cap add android
npx cap sync android
```
Questo genera la cartella `native/android` (resta solo sul tuo PC, non nel repo).

### 1.4 Avvia l'app sul telefono
```
npx cap run android
```
Scegli il tuo telefono dalla lista. Si compila e si installa: **l'app si apre
e carica il sito live**. 🎉

> In alternativa: `npx cap open android` apre il progetto in Android Studio,
> poi premi il tasto **Run** (▶).

**✅ Traguardo Tappa 1**: l'app parte, a schermo intero, e vedi Hair Studios.
Ancora niente push native — le aggiungiamo alla Tappa 2.

Quando ci sei, dimmelo e passiamo alla Tappa 2.

---

## TAPPA 2 · Notifiche push native (FCM)

Prerequisiti già fatti: progetto Firebase creato, `google-services.json` in
`native/android/app/`, app ricompilata. Il codice web delle push è già online
(l'app lo carica dal sito). Restano 3 cose, tutte su Supabase/Firebase.

### 2.1 Tabella dei token
Supabase → **SQL Editor** → esegui [`patch_push_native.sql`](patch_push_native.sql)
(crea la tabella `push_tokens`).

### 2.2 Credenziale per inviare (Service Account Firebase)
1. [Firebase Console](https://console.firebase.google.com) → il tuo progetto →
   ingranaggio **Impostazioni progetto** → scheda **Account di servizio**
2. **Genera nuova chiave privata** → scarica il file **JSON** (⚠️ è segreto,
   non metterlo nel repo né condividerlo)
3. Apri il file, copia **tutto** il suo contenuto

### 2.3 Aggiorna la Edge Function e il secret
1. Supabase → **Edge Functions → send-push** → **Edit** → incolla la nuova
   versione di
   [`supabase/functions/send-push/index.ts`](supabase/functions/send-push/index.ts)
   → **Deploy**
2. **Edge Functions → Secrets** → aggiungi:
   | Nome | Valore |
   |---|---|
   | `FCM_SERVICE_ACCOUNT` | tutto il contenuto del JSON del punto 2.2 |

   (I secret VAPID restano: servono ancora per le push web dei clienti iPhone
   non-app e dei browser.)

### 2.4 Prova
1. Apri l'app sul telefono → **Account → Attiva le notifiche** → compare la
   **finestra di sistema NATIVA** di Android → Consenti.
2. Da un altro account (o dal sito) crea/conferma una prenotazione.
3. La notifica arriva sull'app come notifica nativa. 🎉
   Se non arriva, controlla i log: Supabase → Edge Functions → send-push → Logs.

## TAPPA 3 · Build di release e caricamento su Play — *dopo la Tappa 2*

1. Firmi l'app con **lo stesso keystore di upload** già usato
   (`signing.keystore`, password `pFUYq0Fscn57`, alias `my-key-alias`) e con
   **version code più alto** dell'ultimo caricato.
2. Generi l'`.aab` di release da Android Studio.
3. Lo carichi nel canale di test della Play Console (stesso package/listing).

---

### Note utili
- **appId**: `com.hairstudiosbarbershop.twa` — invariato, così aggiorna
  l'app già presente sulla Play Console (niente nuovo listing).
- **Aggiornamenti**: l'app carica il sito live, quindi ogni modifica al sito
  arriva subito nell'app senza ripubblicare — come con la TWA.
