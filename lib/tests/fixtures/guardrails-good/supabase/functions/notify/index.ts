import { Resend } from "npm:resend";

const resend = new Resend(Deno.env.get("RESEND_API_KEY"));

Deno.serve(async (request) => {
  const user = await getUser(request);
  const contact = await loadContact(user.id);
  if (!contact.consent_at || contact.unsubscribed_at) {
    return new Response("skipped");
  }
  const link = unsubscribeUrl(contact.id);
  await resend.emails.send({
    to: contact.email,
    subject: "News",
    html: `<p>Hello</p><a href="${link}">Unsubscribe</a>`,
    headers: {
      "List-Unsubscribe": `<${link}>`,
      "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
    },
  });
  return new Response("sent");
});
