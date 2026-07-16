// ============================================================
// Hair Studios – Edge Function "send-push"
// Invia notifiche ai destinatari giusti in base all'evento:
//  - Web Push (VAPID) ai browser/PWA iscritti  (tabella push_subscriptions)
//  - FCM (Firebase) all'app nativa Android/iOS  (tabella push_tokens)
// Chiamata dal frontend dopo le azioni sulle prenotazioni e dal job
// dei promemoria (send_due_reminders).
//
// Secrets richiesti (Dashboard → Edge Functions → Secrets):
//   VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY / VAPID_SUBJECT   (web push)
//   FCM_SERVICE_ACCOUNT  = JSON del service account Firebase (per l'app nativa)
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY sono forniti in automatico.
// ============================================================

import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

webpush.setVapidDetails(
  Deno.env.get('VAPID_SUBJECT') ?? 'mailto:info@hairstudiosbarbershop.com',
  Deno.env.get('VAPID_PUBLIC_KEY')!,
  Deno.env.get('VAPID_PRIVATE_KEY')!,
);

// Service account Firebase (facoltativo: se assente, si invia solo web push)
let FCM_SA: { client_email: string; private_key: string; project_id: string } | null = null;
try { const raw = Deno.env.get('FCM_SERVICE_ACCOUNT'); if (raw) FCM_SA = JSON.parse(raw); }
catch (e) { console.error('FCM_SERVICE_ACCOUNT non valido:', e); }

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });

// ── FCM v1: OAuth2 con JWT firmato dal service account ───────────
const b64url = (data: Uint8Array | string): string => {
  const bin = typeof data === 'string' ? data : String.fromCharCode(...data);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
const pemToBuf = (pem: string): ArrayBuffer => {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
};
async function getFcmAccessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim  = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600,
  }));
  const key = await crypto.subtle.importKey('pkcs8', pemToBuf(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key,
    new TextEncoder().encode(`${header}.${claim}`)));
  const jwt = `${header}.${claim}.${b64url(sig)}`;
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const j = await res.json();
  if (!j.access_token) throw new Error('FCM token: ' + JSON.stringify(j));
  return j.access_token;
}

// Eventi diretti al CLIENTE (booking.user_id) o al BARBIERE (admin)
const TO_CLIENT = new Set(['confirmed', 'cancelled_by_staff', 'moved', 'reminder']);
const TO_BARBER = new Set(['new_booking', 'cancelled_by_client']);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    const { booking_id, event } = await req.json();
    if (!booking_id || !event) return json({ error: 'Parametri mancanti' }, 400);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    const { data: bk } = await admin.from('bookings').select('*').eq('id', booking_id).single();
    if (!bk) return json({ error: 'Prenotazione non trovata' }, 404);

    const { data: st } = await admin.from('staff').select('name').eq('id', bk.staff_id).single();

    // Data/ora sono in ora italiana: 'Z' + timeZone UTC evita conversioni
    const quando = new Date(`${bk.date}T${bk.time}Z`).toLocaleString('it-IT', {
      weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit', timeZone: 'UTC',
    });
    const barbiere = st?.name || 'il barbiere';

    const M: Record<string, { title: string; body: string; url: string }> = {
      confirmed:           { title: 'Prenotazione confermata ✓', body: `${bk.service_name}: ${quando} con ${barbiere}. Ti aspettiamo!`, url: '/?shortcut=prenotazioni' },
      cancelled_by_staff:  { title: 'Prenotazione annullata',    body: `Il tuo appuntamento del ${quando} è stato annullato. Contattaci per riprenotare.`, url: '/?shortcut=prenotazioni' },
      moved:               { title: 'Appuntamento spostato',     body: `Il tuo appuntamento è stato spostato a ${quando} con ${barbiere}.`, url: '/?shortcut=prenotazioni' },
      reminder:            { title: 'Promemoria appuntamento ✂️', body: `${quando}: hai ${bk.service_name} con ${barbiere}. A presto!`, url: '/?shortcut=prenotazioni' },
      new_booking:         { title: 'Nuova prenotazione da confermare', body: `${bk.client_name}: ${bk.service_name}, ${quando}.`, url: '/' },
      cancelled_by_client: { title: 'Prenotazione annullata dal cliente', body: `${bk.client_name} ha annullato: ${bk.service_name}, ${quando}. Slot di nuovo libero.`, url: '/' },
    };
    const msg = M[event];
    if (!msg) return json({ error: 'Evento non valido' }, 400);

    // Destinatari
    let userIds: string[] = [];
    if (TO_CLIENT.has(event)) {
      if (bk.user_id) userIds = [bk.user_id];
    } else if (TO_BARBER.has(event)) {
      const { data: admins } = await admin.from('profiles').select('id, staff_id').eq('is_admin', true);
      userIds = (admins || []).filter(p => p.staff_id === bk.staff_id || p.staff_id === null).map(p => p.id);
    }
    if (!userIds.length) return json({ ok: true, sent: 0 });

    let sent = 0;

    // 1) WEB PUSH (browser/PWA)
    const { data: subs } = await admin.from('push_subscriptions').select('*').in('user_id', userIds);
    if (subs?.length) {
      const payload = JSON.stringify({ title: msg.title, body: msg.body, url: msg.url, tag: `booking-${booking_id}` });
      await Promise.all(subs.map(async (s) => {
        try {
          await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload);
          sent++;
        } catch (err) {
          const code = (err as { statusCode?: number }).statusCode;
          if (code === 404 || code === 410) await admin.from('push_subscriptions').delete().eq('endpoint', s.endpoint);
          else console.error('web push error:', code, err);
        }
      }));
    }

    // 2) FCM (app nativa Android/iOS)
    const { data: tokens } = await admin.from('push_tokens').select('*').in('user_id', userIds);
    if (tokens?.length && FCM_SA) {
      const at = await getFcmAccessToken(FCM_SA);
      const endpoint = `https://fcm.googleapis.com/v1/projects/${FCM_SA.project_id}/messages:send`;
      await Promise.all(tokens.map(async (t) => {
        try {
          const r = await fetch(endpoint, {
            method: 'POST',
            headers: { Authorization: `Bearer ${at}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({
              message: {
                token: t.token,
                notification: { title: msg.title, body: msg.body },
                data: { url: msg.url },
                android: { priority: 'HIGH', notification: { sound: 'default' } },
                apns: { payload: { aps: { sound: 'default' } } },
              },
            }),
          });
          if (r.ok) { sent++; return; }
          const errBody = await r.text();
          // token non più valido → rimuovilo
          if (r.status === 404 || /UNREGISTERED|INVALID_ARGUMENT/.test(errBody)) {
            await admin.from('push_tokens').delete().eq('token', t.token);
          } else {
            console.error('fcm error:', r.status, errBody);
          }
        } catch (e) { console.error('fcm send:', e); }
      }));
    }

    return json({ ok: true, sent });
  } catch (e) {
    console.error('send-push error:', e);
    return json({ error: String(e) }, 500);
  }
});
