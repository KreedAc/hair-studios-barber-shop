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

## TAPPA 2 · Notifiche push native (FCM) — *la faremo insieme dopo*

In sintesi (per sapere cosa ci aspetta):
1. Crei un progetto **Firebase** gratuito e ci colleghi il package
   `com.hairstudiosbarbershop.twa`.
2. Scarichi `google-services.json` e lo metti in `native/android/app/`.
3. Aggiungiamo il plugin push (già in `package.json`) e il codice di
   registrazione (lo preparo io nel sito).
4. Aggiorno la Edge Function su Supabase per inviare via FCM.

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
