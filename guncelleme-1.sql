-- GÜNCELLEME 1: Öğrenci kimlik bilgileri (kod, e-posta, verilen şifre)
-- SQL Editor'de bir kez çalıştır. Idempotent.
alter table students add column if not exists kod text;
alter table students add column if not exists email text;
alter table students add column if not exists initial_password text;
-- Not: initial_password öğretmenin verdiği şifredir; yalnızca sahibi (RLS: owner)
-- görebilir. Giriş güvenliği bundan bağımsızdır (auth tarafı hash ile çalışır).
