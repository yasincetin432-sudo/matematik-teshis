// ============================================================================
// ai-proxy v3 — ÇOKLU SAĞLAYICI: Anthropic (Claude) VE/VEYA Google Gemini.
// Hangi anahtar ekliyse onu kullanır; ikisi de varsa AI_PROVIDER secret'ı seçer.
//   Secrets:
//     GEMINI_API_KEY     (ücretsiz: aistudio.google.com/apikey)
//     ANTHROPIC_API_KEY  (ücretli, isteğe bağlı)
//     AI_PROVIDER        (ops.: "gemini" | "anthropic")
//     GEMINI_MODEL       (ops., varsayılan: gemini-2.0-flash)
//     ANTHROPIC_MODEL    (ops., varsayılan: claude-sonnet-4-6)
// Eylemler: generate | classify_pool | classify | karne | extract_pool
// ============================================================================

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const AI_PROVIDER = (Deno.env.get("AI_PROVIDER") ?? "").toLowerCase();
const ANTHROPIC_MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6";
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash";

const QTYPES = [
  ["islem","Doğrudan işlem/hesap"],["kavram","Kavram/tanım yorumu"],
  ["sozel","Sözel/kurma problemi"],["grafik","Grafik/şekil/tablo yorumu"],
  ["muhakeme","Akıl yürütme / çok adımlı çıkarım"],["coklu","Çok kavramlı entegrasyon"],
];
const QTYPE_STR = QTYPES.map(([i,d]) => i+" = "+d).join("; ");

const cors: Record<string,string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s=200) => new Response(JSON.stringify(b), { status:s, headers:{...cors,"content-type":"application/json"} });
const parseJson = (t: string) => JSON.parse(t.replace(/```json|```/g,"").trim());
const listStr = (topics: any[]) => (topics??[]).map((t)=>t.id+" = "+t.name+" ["+t.section+"]").join("\n");

function pickProvider(): "anthropic"|"gemini" {
  if (AI_PROVIDER === "gemini" && GEMINI_API_KEY) return "gemini";
  if (AI_PROVIDER === "anthropic" && ANTHROPIC_API_KEY) return "anthropic";
  if (ANTHROPIC_API_KEY) return "anthropic";
  if (GEMINI_API_KEY) return "gemini";
  throw new Error("AI anahtarı tanımlı değil. Supabase Secrets'a GEMINI_API_KEY (ücretsiz) veya ANTHROPIC_API_KEY ekleyin.");
}

type Parts = { text: string; pdfBase64?: string; imageBase64?: string; mediaType?: string };

async function callAI(p: Parts, maxTokens=3000): Promise<string> {
  const provider = pickProvider();
  if (provider === "anthropic") {
    const content: any[] = [];
    if (p.pdfBase64)   content.push({ type:"document", source:{ type:"base64", media_type:"application/pdf", data:p.pdfBase64 } });
    if (p.imageBase64) content.push({ type:"image",    source:{ type:"base64", media_type:p.mediaType||"image/jpeg", data:p.imageBase64 } });
    content.push({ type:"text", text:p.text });
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method:"POST",
      headers:{ "content-type":"application/json", "x-api-key":ANTHROPIC_API_KEY, "anthropic-version":"2023-06-01" },
      body: JSON.stringify({ model:ANTHROPIC_MODEL, max_tokens:maxTokens, messages:[{ role:"user", content }] }),
    });
    const d = await r.json();
    if (d.error) throw new Error("Anthropic: " + (d.error?.message ?? "hata"));
    return (d.content??[]).filter((b:any)=>b.type==="text").map((b:any)=>b.text).join("\n");
  } else {
    const parts: any[] = [];
    if (p.pdfBase64)   parts.push({ inline_data:{ mime_type:"application/pdf", data:p.pdfBase64 } });
    if (p.imageBase64) parts.push({ inline_data:{ mime_type:p.mediaType||"image/jpeg", data:p.imageBase64 } });
    parts.push({ text:p.text });
    const url = "https://generativelanguage.googleapis.com/v1beta/models/"+GEMINI_MODEL+":generateContent?key="+GEMINI_API_KEY;
    const r = await fetch(url, {
      method:"POST", headers:{ "content-type":"application/json" },
      body: JSON.stringify({ contents:[{ role:"user", parts }], generationConfig:{ maxOutputTokens:maxTokens } }),
    });
    const d = await r.json();
    if (d.error) throw new Error("Gemini: " + (d.error?.message ?? "hata"));
    const out = (d.candidates?.[0]?.content?.parts ?? []).map((x:any)=>x.text??"").join("");
    if (!out) throw new Error("Gemini boş yanıt döndürdü.");
    return out;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error:"POST bekleniyor" }, 405);
  try {
    const body = await req.json();
    const action = body.action;

    if (action === "generate") {
      const { topicName, section, difficulty, n = 2, qtypes } = body;
      const wanted = Array.isArray(qtypes) && qtypes.length ? qtypes : null;
      const cesit = wanted ? "Soruları ŞU çeşitlere dağıt: "+wanted.join(", ")+"."
        : "Soruları farklı çeşitlere yay. Geçerli çeşitler: "+QTYPES.map(([i])=>i).join(", ")+".";
      const prompt = "Sen deneyimli bir YKS matematik soru yazarısın. "+section+" Matematik, \""+topicName+"\" konusundan ÖSYM tarzında "+n+" adet "+difficulty+" zorlukta çoktan seçmeli (A-E) soru üret. "+cesit+" Her sorunun TEK doğru cevabı olsun. Matematiği okunabilir yaz (² √ a/b ∫ lim). GERÇEK şekil/grafik gerektiren soru ÜRETME. cozum kısa olsun. Çeşit sözlüğü: "+QTYPE_STR+". ÇIKTI SADECE JSON:\n{\"sorular\":[{\"soru\":\"\",\"secenekler\":{\"A\":\"\",\"B\":\"\",\"C\":\"\",\"D\":\"\",\"E\":\"\"},\"dogru\":\"C\",\"cozum\":\"\",\"cesit\":\"islem\",\"has_figure\":false}]}";
      return json(parseJson(await callAI({ text: prompt }, 3800)));
    }

    if (action === "classify_pool") {
      const { soru, secenekler, topicList } = body;
      const secStr = secenekler ? "\nŞıklar: "+JSON.stringify(secenekler) : "";
      const prompt = "Aşağıdaki YKS matematik sorusunu sınıfla: (1) tek konu id, (2) zorluk temel|kolay|orta|zor, (3) çeşit ["+QTYPES.map(([i])=>i).join("|")+"], (4) has_figure. Çeşitler: "+QTYPE_STR+". ÇIKTI SADECE JSON:\n{\"topic_id\":\"\",\"difficulty\":\"orta\",\"qtype\":\"islem\",\"has_figure\":false}\n\nKONULAR:\n"+listStr(topicList)+"\n\nSORU:\n"+soru+secStr;
      return json(parseJson(await callAI({ text: prompt }, 600)));
    }

    if (action === "classify") {
      const { imageBase64, mediaType, topicList } = body;
      const prompt = "Ekteki görsel bir YKS matematik sorusudur. Listeden TEK konuyu seç ve çeşidini belirle. Çeşitler: "+QTYPE_STR+". ÇIKTI SADECE JSON:\n{\"id\":\"ayt_turev\",\"qtype\":\"grafik\",\"gerekce\":\"kısa\"}\n\nKONULAR:\n"+listStr(topicList);
      return json(parseJson(await callAI({ text: prompt, imageBase64, mediaType }, 500)));
    }

    if (action === "karne") {
      const { pdfBase64, topicList } = body;
      const prompt = "Ekteki PDF bir öğrencinin matematik deneme KARNESİDİR. Her konunun Doğru(d), Yanlış(y), Boş(b) sayısını çıkar; adları en yakın id ile eşle. Yalnızca karnede görünen konuları döndür. ÇIKTI SADECE JSON:\n{\"results\":[{\"id\":\"tyt_p_sayi\",\"d\":2,\"y\":1,\"b\":0}]}\n\nKONULAR:\n"+listStr(topicList);
      return json(parseJson(await callAI({ text: prompt, pdfBase64 }, 2000)));
    }

    if (action === "extract_pool") {
      const { pdfBase64, imageBase64, mediaType, topicList } = body;
      const prompt = "Ekteki belge/görsel YKS matematik soruları içerir. İçindeki TÜM çoktan seçmeli soruları çıkar. Her soru için: topic_id (listeden en uygun), difficulty (temel|kolay|orta|zor), qtype ("+QTYPES.map(([i])=>i).join("|")+"), soru metni, secenekler (A-E), dogru (cevap anahtarı görünmüyorsa SORUYU ÇÖZ ve doğru şıkkı belirle), cozum (kısa). Şekil/grafik olmadan anlaşılamayan soruları has_figure:true işaretle. Çeşitler: "+QTYPE_STR+". ÇIKTI SADECE JSON:\n{\"sorular\":[{\"topic_id\":\"\",\"difficulty\":\"orta\",\"qtype\":\"islem\",\"soru\":\"\",\"secenekler\":{\"A\":\"\",\"B\":\"\",\"C\":\"\",\"D\":\"\",\"E\":\"\"},\"dogru\":\"C\",\"cozum\":\"\",\"has_figure\":false}]}\n\nKONULAR:\n"+listStr(topicList);
      return json(parseJson(await callAI({ text: prompt, pdfBase64, imageBase64, mediaType }, 8000)));
    }

    return json({ error:"bilinmeyen action" }, 400);
  } catch (e) { return json({ error:String(e) }, 500); }
});
