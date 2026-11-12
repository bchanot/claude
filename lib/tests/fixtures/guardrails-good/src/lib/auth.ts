import { createClient } from "@supabase/supabase-js";

export async function getUser(request: Request) {
  const header = request.headers.get("authorization") ?? "";
  const token = header.replace("Bearer ", "");
  if (!token) return null;
  const sb = createClient(
    process.env.SUPABASE_URL!, process.env.SUPABASE_ANON_KEY!);
  const { data } = await sb.auth.getUser(token);
  return data.user;
}
