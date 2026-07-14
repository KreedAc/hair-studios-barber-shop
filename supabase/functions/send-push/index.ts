// ============================================================
// Hair Studios – Edge Function "send-push"
// Invia notifiche push web (VAPID) ai destinatari giusti in base
// all'evento. Chiamata dal frontend dopo le azioni sulle prenotazioni
// e dal job dei promemoria (send_due_reminders).
//
// Secrets richiesti (Dashboard → Edge Functions → Secrets):
//   VAPID_PUBLIC_KEY    chiave pubblica VAPID
//   VAPID_PRIVATE_KEY   chiave privata VAPID
//   VAPID_SUBJECT       es. "mailto:info@hairstudiosbarbershop.com"
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

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });

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

    // Testo per ogni tipo di evento
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

    // Trova gli user_id destinatari
    let userIds: string[] = [];
    if (TO_CLIENT.has(event)) {
      if (bk.user_id) userIds = [bk.user_id];
    } else if (TO_BARBER.has(event)) {
      // barbiere assegnato + super admin (staff_id null)
      const { data: admins } = await admin
        .from('profiles').select('id, staff_id').eq('is_admin', true);
      userIds = (admins || [])
        .filter(p => p.staff_id === bk.staff_id || p.staff_id === null)
        .map(p => p.id);
    }
    if (!userIds.length) return json({ ok: true, sent: 0 });

    const { data: subs } = await admin
      .from('push_subscriptions').select('*').in('user_id', userIds);
    if (!subs?.length) return json({ ok: true, sent: 0 });

    const payload = JSON.stringify({ title: msg.title, body: msg.body, url: msg.url, tag: `booking-${booking_id}` });

    let sent = 0;
    await Promise.all(subs.map(async (s) => {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          payload,
        );
        sent++;
      } catch (err) {
        // 404/410 = iscrizione scaduta → rimuovila
        const code = (err as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) {
          await admin.from('push_subscriptions').delete().eq('endpoint', s.endpoint);
        } else {
          console.error('push send error:', code, err);
        }
      }
    }));

    return json({ ok: true, sent });
  } catch (e) {
    console.error('send-push error:', e);
    return json({ error: String(e) }, 500);
  }
});
