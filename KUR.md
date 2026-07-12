# KURULUM — Komut satırı YOK, dosya düzenleme YOK

Toplam ~25 dakika, hepsi tarayıcıda. Sırayla:

## 1) Supabase hesabı ve proje (5 dk)
supabase.com → ücretsiz kayıt → "New Project" → ad ver, güçlü DB şifresi seç → Create.

## 2) Veritabanını kur (2 dk)
Sol menü **SQL Editor** → "New query" → bu paketteki `setup.sql` dosyasını
Not Defteri ile açıp TÜMÜNÜ kopyala → yapıştır → **Run**. "Success" görmelisin.

## 3) Kendi öğretmen hesabını aç (1 dk)
Sol menü **Authentication → Users → Add user** → e-postanı ve bir şifre yaz → Create.
(Bu hesap otomatik "yetkili" olur.)

## 4) İki fonksiyonu panodan kur (5 dk — CLI yok)
Sol menü **Edge Functions → Deploy a new function → Via Editor**:
- Ad: `ai-proxy` → editöre bu paketteki `fonksiyonlar/ai-proxy.ts` içeriğini yapıştır → Deploy.
- Aynısını `admin-create-student` adı ve `fonksiyonlar/admin-create-student.ts` içeriğiyle tekrarla.
Sonra **Edge Functions → Secrets** (veya Project Settings → Edge Functions):
`ANTHROPIC_API_KEY` adında bir secret ekle; değeri console.anthropic.com'dan
alacağın API anahtarı (sk-ant-...).

## 5) Uygulamayı yayınla (2 dk)
Tarayıcıda **app.netlify.com/drop** → bu `kurulum-paketi` klasörünü pencereye
sürükle-bırak → sana `https://xxxx.netlify.app` gibi bir adres verir.

## 6) Aç ve kur (2 dk)
Adresi aç → "Yönetim (Öğretmen)"e gir → **ilk açılışta URL + anon key sorar**:
Supabase panosunda **Project Settings → API** sayfasındaki "Project URL" ve
"anon public" anahtarını yapıştır → Kaydet. 3. adımdaki e-posta/şifreyle gir.

Telefona kurmak: Android Chrome → ⋮ menü → **"Uygulamayı yükle"**.
Bilgisayara: adres çubuğundaki kur simgesi → Yükle.
Öğrencilere yalnızca `.../ogrenci/` adresini ver; onlar da aynı yolla kurabilir.

## Sorun olursa
- SQL hatası: setup.sql'i eksik kopyalamış olabilirsin; tümünü seçip yeniden dene.
- Fonksiyon 401/403: 3. adımdaki hesapla giriş yaptığından emin ol.
- "Uygulamayı yükle" görünmüyor: adres https:// ile açık olmalı (Netlify verir).
