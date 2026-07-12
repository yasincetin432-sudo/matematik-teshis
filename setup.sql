-- ############################################################################
-- YKS MATEMATİK TEŞHİS & TEDAVİ — BİRLEŞİK KURULUM (setup.sql)
-- Program + soru havuzu + roller (yetkili/öğrenci) + öğrenci platformu, tek dosyada.
-- Supabase > SQL Editor'de bir kez çalıştır. Idempotenttir.
-- (Bu dosya, önceki schema.sql + schema_v2_qtypes.sql dosyalarının yerine geçer.)
-- ############################################################################

create extension if not exists pgcrypto;

-- ===== ENUM'lar =====
do $$ begin create type difficulty_t as enum ('temel','kolay','orta','zor'); exception when duplicate_object then null; end $$;
do $$ begin create type qstatus_t   as enum ('taslak','dogrulandi','reddedildi'); exception when duplicate_object then null; end $$;
do $$ begin create type qsource_t   as enum ('uretildi','cikmis','ogretmen'); exception when duplicate_object then null; end $$;
do $$ begin create type qtype_t      as enum ('islem','kavram','sozel','grafik','muhakeme','coklu'); exception when duplicate_object then null; end $$;

-- ===== Konu taksonomisi (paylaşımlı, salt-okunur) =====
create table if not exists topics (
  id text primary key, section text not null check (section in ('TYT','AYT')),
  grp text not null, name text not null, default_count int not null default 0
);
insert into topics (id, section, grp, name, default_count) values
  ('tyt_temel','TYT','Sayılar','Temel Kavramlar',1),
  ('tyt_basamak','TYT','Sayılar','Sayı Basamakları',1),
  ('tyt_bolme','TYT','Sayılar','Bölme - Bölünebilme',1),
  ('tyt_ebob','TYT','Sayılar','EBOB - EKOK',0),
  ('tyt_rasyo','TYT','Sayılar','Rasyonel Sayılar',1),
  ('tyt_uslu','TYT','Sayılar','Üslü Sayılar',1),
  ('tyt_koklu','TYT','Sayılar','Köklü Sayılar',1),
  ('tyt_mutlak','TYT','Cebir','Mutlak Değer',1),
  ('tyt_esitsiz','TYT','Cebir','Eşitsizlikler',0),
  ('tyt_carpan','TYT','Cebir','Çarpanlara Ayırma',0),
  ('tyt_oran','TYT','Cebir','Oran - Orantı',1),
  ('tyt_denklem','TYT','Cebir','Denklem Çözme',1),
  ('tyt_kume','TYT','Cebir','Kümeler',1),
  ('tyt_mantik','TYT','Cebir','Mantık',1),
  ('tyt_fonk','TYT','Cebir','Fonksiyonlar',1),
  ('tyt_p_sayi','TYT','Problemler','Sayı - Kesir Problemleri',2),
  ('tyt_p_yas','TYT','Problemler','Yaş Problemleri',1),
  ('tyt_p_yuzde','TYT','Problemler','Yüzde - Kâr/Zarar',1),
  ('tyt_p_kar','TYT','Problemler','Karışım Problemleri',1),
  ('tyt_p_har','TYT','Problemler','Hareket Problemleri',1),
  ('tyt_p_isci','TYT','Problemler','İşçi - Havuz Problemleri',1),
  ('tyt_p_graf','TYT','Problemler','Grafik - Tablo Problemleri',1),
  ('tyt_p_rutin','TYT','Problemler','Rutin Olmayan Problemler',2),
  ('tyt_perm','TYT','Olasılık & Veri','Permütasyon - Kombinasyon',1),
  ('tyt_olas','TYT','Olasılık & Veri','Olasılık',1),
  ('tyt_istat','TYT','Olasılık & Veri','Veri - İstatistik',2),
  ('tyt_g_aci','TYT','Geometri','Doğruda - Üçgende Açılar',2),
  ('tyt_g_ucgen','TYT','Geometri','Özel / Dik Üçgenler',1),
  ('tyt_g_alan','TYT','Geometri','Üçgende Alan - Benzerlik',2),
  ('tyt_g_dortg','TYT','Geometri','Çokgenler - Dörtgenler',2),
  ('tyt_g_cember','TYT','Geometri','Çember - Daire',1),
  ('tyt_g_anali','TYT','Geometri','Analitik Geometri (Doğru)',1),
  ('tyt_g_kati','TYT','Geometri','Katı Cisimler',2),
  ('ayt_fonk','AYT','Cebir','Fonksiyonlar (ileri)',2),
  ('ayt_polinom','AYT','Cebir','Polinomlar',2),
  ('ayt_parabol','AYT','Cebir','2. Derece Denklem - Parabol',2),
  ('ayt_esitsiz','AYT','Cebir','Eşitsizlikler',1),
  ('ayt_karmasik','AYT','Cebir','Karmaşık Sayılar',1),
  ('ayt_perm','AYT','Cebir','Permütasyon - Kombinasyon',1),
  ('ayt_binom','AYT','Cebir','Binom',1),
  ('ayt_olas','AYT','Cebir','Olasılık',1),
  ('ayt_trig','AYT','Analiz','Trigonometri',4),
  ('ayt_log','AYT','Analiz','Logaritma (Üstel-Log.)',2),
  ('ayt_dizi','AYT','Analiz','Diziler',2),
  ('ayt_limit','AYT','Analiz','Limit ve Süreklilik',3),
  ('ayt_turev','AYT','Analiz','Türev',4),
  ('ayt_turevu','AYT','Analiz','Türevin Uygulamaları',2),
  ('ayt_int1','AYT','Analiz','Belirsiz İntegral',2),
  ('ayt_int2','AYT','Analiz','Belirli İntegral - Uygulama',2),
  ('ayt_g_ucgen','AYT','Geometri','Üçgenler',1),
  ('ayt_g_dortg','AYT','Geometri','Dörtgenler - Çokgenler',1),
  ('ayt_g_cember','AYT','Geometri','Çember - Daire',1),
  ('ayt_g_dogru','AYT','Geometri','Analitik Geo: Doğru',1),
  ('ayt_g_canali','AYT','Geometri','Analitik Geo: Çember',1),
  ('ayt_g_donus','AYT','Geometri','Dönüşüm Geometrisi',1),
  ('ayt_g_kati','AYT','Geometri','Katı Cisimler',1)
on conflict (id) do update set section=excluded.section, grp=excluded.grp, name=excluded.name, default_count=excluded.default_count;

-- ===== SORU HAVUZU (paylaşımlı) =====
create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  topic_id text not null references topics(id),
  difficulty difficulty_t not null,
  qtype qtype_t, has_figure boolean not null default false,
  stem text not null, options jsonb not null,
  correct char(1) not null check (correct in ('A','B','C','D','E')),
  solution text, status qstatus_t not null default 'taslak', source qsource_t not null default 'uretildi',
  content_hash text unique,
  created_by uuid references auth.users(id) default auth.uid(),
  verified_by uuid references auth.users(id), verified_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_questions_lookup on questions (topic_id, difficulty, qtype, status);

-- ===== Öğrenci / Deneme / Sonuç / Kullanım =====
create table if not exists students (
  id uuid primary key default gen_random_uuid(), name text not null,
  owner uuid not null references auth.users(id) default auth.uid(), created_at timestamptz not null default now()
);
create table if not exists exams (
  id uuid primary key default gen_random_uuid(), name text not null, exam_date date,
  counts jsonb not null default '{}'::jsonb,
  owner uuid not null references auth.users(id) default auth.uid(), created_at timestamptz not null default now()
);
create table if not exists results (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  exam_id uuid not null references exams(id) on delete cascade,
  topic_id text not null references topics(id),
  count int not null default 0 check (count>=0),
  wrong int not null default 0 check (wrong>=0),
  blank int not null default 0 check (blank>=0),
  correct int generated always as (greatest(0, count - wrong - blank)) stored,
  owner uuid not null references auth.users(id) default auth.uid(),
  updated_at timestamptz not null default now(),
  unique (student_id, exam_id, topic_id)
);
create index if not exists idx_results_student on results (student_id);
create table if not exists question_usage (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references questions(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  served_at timestamptz not null default now(), context text,
  owner uuid not null references auth.users(id) default auth.uid(),
  unique (question_id, student_id)
);

-- ===== Çeşit hedef dağılımı + kapsam görünümü =====
create table if not exists qtype_targets (
  section text not null check (section in ('TYT','AYT')), grp text not null,
  qtype qtype_t not null, weight numeric not null default 0 check (weight>=0),
  primary key (section, grp, qtype)
);
insert into qtype_targets (section, grp, qtype, weight) values
  ('TYT','Sayılar','islem',0.35),
  ('TYT','Sayılar','kavram',0.2),
  ('TYT','Sayılar','sozel',0.1),
  ('TYT','Sayılar','grafik',0.05),
  ('TYT','Sayılar','muhakeme',0.2),
  ('TYT','Sayılar','coklu',0.1),
  ('TYT','Cebir','islem',0.3),
  ('TYT','Cebir','kavram',0.25),
  ('TYT','Cebir','sozel',0.1),
  ('TYT','Cebir','grafik',0.05),
  ('TYT','Cebir','muhakeme',0.2),
  ('TYT','Cebir','coklu',0.1),
  ('TYT','Problemler','sozel',0.55),
  ('TYT','Problemler','muhakeme',0.25),
  ('TYT','Problemler','islem',0.1),
  ('TYT','Problemler','kavram',0.05),
  ('TYT','Problemler','grafik',0.05),
  ('TYT','Olasılık & Veri','islem',0.3),
  ('TYT','Olasılık & Veri','kavram',0.2),
  ('TYT','Olasılık & Veri','sozel',0.2),
  ('TYT','Olasılık & Veri','grafik',0.15),
  ('TYT','Olasılık & Veri','muhakeme',0.1),
  ('TYT','Olasılık & Veri','coklu',0.05),
  ('TYT','Geometri','islem',0.35),
  ('TYT','Geometri','grafik',0.3),
  ('TYT','Geometri','kavram',0.15),
  ('TYT','Geometri','muhakeme',0.1),
  ('TYT','Geometri','coklu',0.1),
  ('AYT','Cebir','islem',0.35),
  ('AYT','Cebir','kavram',0.2),
  ('AYT','Cebir','muhakeme',0.2),
  ('AYT','Cebir','coklu',0.15),
  ('AYT','Cebir','grafik',0.1),
  ('AYT','Analiz','islem',0.3),
  ('AYT','Analiz','grafik',0.25),
  ('AYT','Analiz','kavram',0.15),
  ('AYT','Analiz','muhakeme',0.2),
  ('AYT','Analiz','coklu',0.1),
  ('AYT','Geometri','islem',0.3),
  ('AYT','Geometri','grafik',0.35),
  ('AYT','Geometri','kavram',0.15),
  ('AYT','Geometri','muhakeme',0.1),
  ('AYT','Geometri','coklu',0.1)
on conflict (section, grp, qtype) do update set weight=excluded.weight;

-- ===== KİTAPÇIK (öğrenciye atanan, kendi içinde bütün) =====
create table if not exists booklets (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  title text, created_at timestamptz not null default now(),
  owner uuid not null references auth.users(id) default auth.uid()
);
create table if not exists booklet_items (
  id uuid primary key default gen_random_uuid(),
  booklet_id uuid not null references booklets(id) on delete cascade,
  question_id uuid references questions(id),
  topic_id text references topics(id), qtype qtype_t, difficulty difficulty_t,
  stem text not null, options jsonb not null, correct char(1), solution text,
  ord int not null default 0
);
create index if not exists idx_booklet_items on booklet_items (booklet_id);

-- ===== ROLLER: profiles + otomatik oluşturma tetikleyicisi =====
create table if not exists profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'ogrenci' check (role in ('yetkili','ogrenci')),
  student_id uuid references students(id) on delete set null,
  teacher_id uuid references auth.users(id),
  display_name text, created_at timestamptz not null default now()
);
-- Yeni kullanıcı: meta veriden rol/öğrenci/öğretmen okunur.
-- Öğrenciler yalnızca admin-create-student fonksiyonuyla (role='ogrenci') oluşturulur;
-- kendi kaydolan (meta yok) => 'yetkili'.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  insert into profiles(user_id, role, student_id, teacher_id, display_name)
  values (new.id,
    coalesce(nullif(new.raw_user_meta_data->>'role',''),'yetkili'),
    nullif(new.raw_user_meta_data->>'student_id','')::uuid,
    nullif(new.raw_user_meta_data->>'teacher_id','')::uuid,
    new.raw_user_meta_data->>'display_name');
  return new;
end $fn$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- ===== Yardımcı güvenlik fonksiyonları (RLS özyinelemesini önler) =====
create or replace function is_yetkili() returns boolean
language sql security definer set search_path = public stable as $fn$
  select exists(select 1 from profiles where user_id = auth.uid() and role = 'yetkili');
$fn$;
create or replace function my_student_id() returns uuid
language sql security definer set search_path = public stable as $fn$
  select student_id from profiles where user_id = auth.uid();
$fn$;

-- ############################################################################
-- ROW LEVEL SECURITY
--  • Yetkili: kendi verisini tam yönetir; havuzu paylaşımlı okur.
--  • Öğrenci: HİÇBİR tabloyu doğrudan sorgulayamaz; yalnızca RPC ile kendi verisi.
-- ############################################################################
alter table topics enable row level security;
alter table questions enable row level security;
alter table students enable row level security;
alter table exams enable row level security;
alter table results enable row level security;
alter table question_usage enable row level security;
alter table qtype_targets enable row level security;
alter table booklets enable row level security;
alter table booklet_items enable row level security;
alter table profiles enable row level security;

drop policy if exists topics_read on topics;
create policy topics_read on topics for select to authenticated using (true);
drop policy if exists qt_read on qtype_targets;
create policy qt_read on qtype_targets for select to authenticated using (is_yetkili());

-- Havuz: yalnızca yetkililer okur/yazar (öğrenciler pool'a doğrudan erişemez)
drop policy if exists q_read on questions;
create policy q_read on questions for select to authenticated using (is_yetkili());
drop policy if exists q_ins on questions;
create policy q_ins on questions for insert to authenticated with check (created_by = auth.uid() and is_yetkili());
drop policy if exists q_upd on questions;
create policy q_upd on questions for update to authenticated using (created_by = auth.uid()) with check (created_by = auth.uid());
drop policy if exists q_del on questions;
create policy q_del on questions for delete to authenticated using (created_by = auth.uid());

-- Özel tablolar: yalnızca sahibi yetkili (öğrenci erişimi RPC üzerinden)
do $pol$
declare t text;
begin
  foreach t in array array['students','exams','results','question_usage','booklets','booklet_items'] loop
    if t = 'booklet_items' then
      execute 'drop policy if exists own_all on booklet_items';
      execute $p$create policy own_all on booklet_items for all to authenticated
        using (exists(select 1 from booklets b where b.id = booklet_items.booklet_id and b.owner = auth.uid()))
        with check (exists(select 1 from booklets b where b.id = booklet_items.booklet_id and b.owner = auth.uid()))$p$;
    else
      execute format('drop policy if exists own_all on %I', t);
      execute format($p$create policy own_all on %I for all to authenticated
        using (owner = auth.uid()) with check (owner = auth.uid())$p$, t);
    end if;
  end loop;
end $pol$;

-- profiles: kendi profilini veya oluşturduğun öğrenci profillerini gör; kendi adını güncelle
drop policy if exists prof_read on profiles;
create policy prof_read on profiles for select to authenticated
  using (user_id = auth.uid() or teacher_id = auth.uid());
drop policy if exists prof_upd on profiles;
create policy prof_upd on profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ############################################################################
-- ÖĞRENCİ RPC'leri (SECURITY DEFINER — yalnızca "kendi verin" döner)
-- ############################################################################
create or replace function get_my_profile() returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare p record;
begin
  select pr.role, pr.display_name, s.name as student_name
    into p from profiles pr left join students s on s.id = pr.student_id
    where pr.user_id = auth.uid();
  if not found then return jsonb_build_object('error','profil yok'); end if;
  return jsonb_build_object('role',p.role,'display_name',p.display_name,'student_name',p.student_name);
end $fn$;

create or replace function get_my_diagnosis() returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare sid uuid; res jsonb;
begin
  sid := my_student_id();
  if sid is null then return jsonb_build_object('error','ogrenci_degil'); end if;
  select jsonb_build_object('konular', coalesce(jsonb_agg(jsonb_build_object(
      'topic_id',x.topic_id,'ad',x.name,'section',x.section,'grp',x.grp,
      'C',x.c,'D',x.d,'Y',x.y,'B',x.b,'basari',round(x.success,3)) order by x.success), '[]'::jsonb))
    into res
  from (
    select r.topic_id, t.name, t.section, t.grp,
      sum(r.count) c, sum(r.correct) d, sum(r.wrong) y, sum(r.blank) b,
      case when sum(r.count)>0 then sum(r.correct)::numeric/sum(r.count) else null end success
    from results r join topics t on t.id = r.topic_id
    where r.student_id = sid and r.count > 0
    group by r.topic_id, t.name, t.section, t.grp
  ) x;
  return coalesce(res, jsonb_build_object('konular','[]'::jsonb));
end $fn$;

create or replace function get_my_booklets() returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare sid uuid; res jsonb;
begin
  sid := my_student_id();
  if sid is null then return '[]'::jsonb; end if;
  -- Öğrenci kopyasında DOĞRU CEVAP ve ÇÖZÜM YER ALMAZ (pratik amaçlı).
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',b.id,'title',b.title,'created_at',b.created_at,
      'items',(select coalesce(jsonb_agg(jsonb_build_object(
                 'ord',i.ord,'topic_id',i.topic_id,'qtype',i.qtype,'difficulty',i.difficulty,
                 'soru',i.stem,'secenekler',i.options) order by i.ord),'[]'::jsonb)
               from booklet_items i where i.booklet_id = b.id)
    ) order by b.created_at desc), '[]'::jsonb)
    into res from booklets b where b.student_id = sid;
  return res;
end $fn$;

grant execute on function get_my_profile(), get_my_diagnosis(), get_my_booklets() to authenticated;

-- ############################################################################
-- Yetkili görünümleri
-- ############################################################################
create or replace view v_student_topic as
select r.owner, r.student_id, r.topic_id, t.section, t.grp, t.name,
  sum(r.count) c, sum(r.correct) d, sum(r.wrong) y, sum(r.blank) b,
  case when sum(r.count)>0 then sum(r.correct)::numeric/sum(r.count) else null end success
from results r join topics t on t.id = r.topic_id
where r.count > 0
group by r.owner, r.student_id, r.topic_id, t.section, t.grp, t.name;

create or replace view v_pool_coverage as
with pool as (
  select t.section, t.grp, q.qtype, count(*)::int n
  from questions q join topics t on t.id = q.topic_id
  where q.status = 'dogrulandi' and q.qtype is not null
  group by t.section, t.grp, q.qtype),
grp_tot as (select section, grp, sum(n) total from pool group by section, grp)
select tg.section, tg.grp, tg.qtype, coalesce(p.n,0) mevcut, round(tg.weight,3) hedef_agirlik,
  case when gt.total>0 then round(coalesce(p.n,0)::numeric/gt.total,3) else 0 end mevcut_pay,
  round(tg.weight - case when gt.total>0 then coalesce(p.n,0)::numeric/gt.total else 0 end,3) acik
from qtype_targets tg
left join pool p on p.section=tg.section and p.grp=tg.grp and p.qtype=tg.qtype
left join grp_tot gt on gt.section=tg.section and gt.grp=tg.grp
order by tg.section, tg.grp, acik desc;
