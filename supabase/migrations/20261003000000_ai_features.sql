-- Funciones de IA adicionales (lectura de etiquetas, estimación por texto y asistente).
-- Cada tipo de uso tiene su propio límite por hora en las Edge Functions.
alter table public.ai_usage add column if not exists kind text not null default 'photo';

drop index if exists public.ai_usage_user_created_idx;
create index if not exists ai_usage_user_kind_created_idx on public.ai_usage (user_id, kind, created_at desc);

-- Limpieza: los registros de uso solo se necesitan para el límite por hora.
create or replace function public.prune_ai_usage()
returns void
language sql
security definer set search_path = ''
as $$
  delete from public.ai_usage where created_at < now() - interval '7 days';
$$;

revoke execute on function public.prune_ai_usage() from public, anon, authenticated;
