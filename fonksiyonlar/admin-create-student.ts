// admin-create-student v2 — öğrenci hesabı açar VE kimlik bilgilerini
// (kod, e-posta, verilen şifre) öğretmenin görebildiği öğrenci kartına yazar.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const EMAIL_DOMAIN = "ogrenci.local";
const cors: Record<string,string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST bekleniyor" }, 405);
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const asUser = createClient(URL, ANON, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: uErr } = await asUser.auth.getUser();
    if (uErr || !user) return json({ error: "oturum yok" }, 401);
    const admin = createClient(URL, SERVICE);
    const { data: prof } = await admin.from("profiles").select("role").eq("user_id", user.id).single();
    if (prof?.role !== "yetkili") return json({ error: "yalnızca yetkili" }, 403);

    const { studentName, kod, sifre, gercekEposta } = await req.json();
    if (!studentName || !kod || !sifre) return json({ error: "studentName, kod, sifre gerekli" }, 400);
    if (String(sifre).length < 6) return json({ error: "şifre en az 6 karakter olmalı" }, 400);
    const kodN = String(kod).trim().toLowerCase();
    const loginEmail = `${kodN}@${EMAIL_DOMAIN}`;

    const { data: st, error: sErr } = await admin.from("students")
      .insert({ name: studentName, owner: user.id, kod: kodN,
                email: (gercekEposta || "").trim() || null, initial_password: String(sifre) })
      .select().single();
    if (sErr) return json({ error: "öğrenci kaydı: " + sErr.message }, 400);

    const { error: cErr } = await admin.auth.admin.createUser({
      email: loginEmail, password: String(sifre), email_confirm: true,
      user_metadata: { role: "ogrenci", student_id: st.id, teacher_id: user.id, display_name: studentName },
    });
    if (cErr) { await admin.from("students").delete().eq("id", st.id);
      return json({ error: "hesap: " + cErr.message }, 400); }
    return json({ ok: true, student_id: st.id, kod: kodN });
  } catch (e) { return json({ error: String(e) }, 500); }
});
