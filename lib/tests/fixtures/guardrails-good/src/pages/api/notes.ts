import { getUser } from "../../lib/auth";

export async function GET(request: Request) {
  const user = await getUser(request);
  if (!user) return new Response("unauthorized", { status: 401 });
  return Response.json({ ok: true });
}
