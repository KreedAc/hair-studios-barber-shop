// ============================================================
// Hair Studios – Edge Function "booking-cancelled"
// Invia le email di annullamento: notifica al barbiere e
// conferma al cliente. Chiamata dal frontend subito dopo
// la RPC cancel_own_booking.
//
// Secrets richiesti (Dashboard → Edge Functions → Secrets):
//   RESEND_API_KEY  chiave API di https://resend.com
//   MAIL_FROM       es. "Hair Studios <prenotazioni@hairstudiosbarbershop.com>"
//                   (il dominio va prima verificato su Resend)
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY sono forniti in automatico.
// ============================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RESEND_KEY   = Deno.env.get('RESEND_API_KEY')!;
const MAIL_FROM    = Deno.env.get('MAIL_FROM') ?? 'Hair Studios <onboarding@resend.dev>';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

async function sendMail(to: string, subject: string, html: string) {
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: MAIL_FROM, to: [to], subject, html }),
  });
  if (!r.ok) console.error(`Resend error (${to}):`, await r.text());
}

const wrap = (title: string, body: string) => `
  <div style="font-family:Georgia,serif;max-width:520px;margin:0 auto;padding:24px;color:#1a1a18">
    <h2 style="margin:0 0 4px;font-weight:700">Hair Studios <span style="color:#b08d3e">Barber Shop</span></h2>
    <p style="margin:0 0 20px;font-size:13px;color:#777">Gizzeria Lido · Lamezia Terme</p>
    <h3 style="margin:0 0 12px">${title}</h3>
    ${body}
    <p style="margin:24px 0 0;font-size:12px;color:#999">Email automatica, non rispondere a questo messaggio.</p>
  </div>`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    const { booking_id } = await req.json();
    if (!booking_id) return json({ error: 'booking_id mancante' }, 400);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // Chi chiama? (il JWT è già stato verificato dalla piattaforma)
    const jwt = req.headers.get('Authorization')?.replace('Bearer ', '') ?? '';
    const { data: { user } } = await admin.auth.getUser(jwt);
    if (!user) return json({ error: 'Non autenticato' }, 401);

    const { data: bk } = await admin.from('bookings').select('*').eq('id', booking_id).single();

    // Si notificano solo annullamenti reali, fatti dal cliente, sulla propria prenotazione
    if (!bk || bk.status !== 'cancelled' || bk.cancelled_by !== 'client' || bk.user_id !== user.id) {
      return json({ error: 'Prenotazione non valida' }, 400);
    }

    const { data: st } = await admin
      .from('staff').select('name, full_name, email').eq('id', bk.staff_id).single();

    // date/time sono in ora italiana: la 'Z' + timeZone UTC evitano conversioni
    const quando = new Date(`${bk.date}T${bk.time}Z`).toLocaleString('it-IT', {
      weekday: 'long', day: 'numeric', month: 'long',
      hour: '2-digit', minute: '2-digit', timeZone: 'UTC',
    });

    const sends: Promise<void>[] = [];

    // 1. Notifica al barbiere
    if (st?.email) {
      sends.push(sendMail(
        st.email,
        `Prenotazione annullata: ${bk.client_name} – ${quando}`,
        wrap('Prenotazione annullata da un cliente', `
          <p style="font-size:15px;line-height:1.6">
            <strong>${bk.client_name}</strong> ha annullato il suo appuntamento:</p>
          <table style="font-size:14px;line-height:1.8;border-collapse:collapse">
            <tr><td style="color:#777;padding-right:16px">Servizio</td><td><strong>${bk.service_name}</strong> (${bk.service_duration} min)</td></tr>
            <tr><td style="color:#777;padding-right:16px">Quando</td><td><strong>${quando}</strong></td></tr>
            <tr><td style="color:#777;padding-right:16px">Barbiere</td><td>${st.name}</td></tr>
          </table>
          <p style="font-size:14px;margin-top:16px">Lo slot è di nuovo disponibile per altre prenotazioni.</p>
        `),
      ));
    }

    // 2. Conferma di annullamento al cliente
    if (user.email) {
      sends.push(sendMail(
        user.email,
        'Prenotazione annullata – Hair Studios',
        wrap('La tua prenotazione è stata annullata', `
          <p style="font-size:15px;line-height:1.6">Ciao ${bk.client_name},<br/>
            confermiamo l'annullamento del tuo appuntamento:</p>
          <table style="font-size:14px;line-height:1.8;border-collapse:collapse">
            <tr><td style="color:#777;padding-right:16px">Servizio</td><td><strong>${bk.service_name}</strong></td></tr>
            <tr><td style="color:#777;padding-right:16px">Quando</td><td><strong>${quando}</strong></td></tr>
            ${st ? `<tr><td style="color:#777;padding-right:16px">Barbiere</td><td>${st.name}</td></tr>` : ''}
          </table>
          <p style="font-size:14px;margin-top:16px">
            Ti aspettiamo presto! Puoi prenotare un nuovo appuntamento su
            <a href="https://hairstudiosbarbershop.com" style="color:#b08d3e">hairstudiosbarbershop.com</a>.
          </p>
        `),
      ));
    }

    await Promise.all(sends);
    return json({ ok: true });
  } catch (e) {
    console.error('booking-cancelled error:', e);
    return json({ error: String(e) }, 500);
  }
});
