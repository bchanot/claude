import twilio from "npm:twilio";

const client = twilio(Deno.env.get("TWILIO_SID"), Deno.env.get("TWILIO_TOKEN"));

Deno.serve(async (request) => {
  const user = await getUser(request);
  const contact = await loadContact(user.id);
  if (!contact.consent_at || contact.opt_out_at) {
    return new Response("skipped");
  }
  await client.messages.create({
    to: contact.phone,
    body: "Your offer is ready. Reply STOP to opt out.",
  });
  return new Response("sent");
});
