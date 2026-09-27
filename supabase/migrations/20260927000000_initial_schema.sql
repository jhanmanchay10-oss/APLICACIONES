-- NutriSemáforo: esquema inicial
-- Cambios respecto a la propuesta original:
--  * meal_foods guarda una copia de los datos del alimento (nombre, categoría,
--    NOVA, nutrientes ya escalados a la cantidad). Así el historial no cambia
--    si más adelante se corrige el catálogo, y los alimentos detectados por IA
--    no necesitan crear filas en `foods`.
--  * meal_foods incluye user_id para que la política RLS sea directa y rápida.
--  * `foods` es un catálogo compartido de solo lectura para los usuarios.
--  * Se agregan score, source e is_estimate a meals para explicar el resultado.

create extension if not exists "pgcrypto";

-- Perfiles -------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text check (char_length(name) <= 30),
  avatar_path text,
  show_calories boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Catálogo de alimentos (compartido, solo lectura) ----------------------------
create table public.foods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  barcode text unique,
  category text not null default 'other',
  nova_group smallint check (nova_group between 1 and 4),
  serving_size text,
  calories numeric not null default 0,
  protein numeric not null default 0,
  carbohydrates numeric not null default 0,
  fat numeric not null default 0,
  saturated_fat numeric not null default 0,
  fiber numeric not null default 0,
  sugar numeric not null default 0,
  sodium_mg numeric not null default 0,
  ingredients text,
  created_at timestamptz not null default now()
);

-- Comidas ----------------------------------------------------------------------
create table public.meals (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  source text not null check (source in ('photo', 'barcode', 'search')),
  photo_path text,
  traffic_light text not null check (traffic_light in ('green', 'orange', 'red')),
  score smallint not null,
  is_estimate boolean not null default false,
  total_calories numeric not null default 0,
  created_at timestamptz not null default now()
);

create index meals_user_created_idx on public.meals (user_id, created_at desc);

create table public.meal_foods (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null references public.meals (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  food_id uuid references public.foods (id) on delete set null,
  food_name text not null check (char_length(food_name) between 1 and 120),
  barcode text,
  category text not null default 'other',
  nova_group smallint check (nova_group between 1 and 4),
  quantity_grams numeric not null check (quantity_grams > 0 and quantity_grams <= 3000),
  confidence numeric check (confidence between 0 and 1),
  calories numeric not null default 0,
  protein numeric not null default 0,
  carbohydrates numeric not null default 0,
  fat numeric not null default 0,
  saturated_fat numeric not null default 0,
  fiber numeric not null default 0,
  sugar numeric not null default 0,
  sodium_mg numeric not null default 0
);

create index meal_foods_meal_idx on public.meal_foods (meal_id);
create index meal_foods_user_idx on public.meal_foods (user_id);

-- Resúmenes semanales ------------------------------------------------------------
create table public.weekly_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  week_start date not null,
  green_count integer not null default 0,
  orange_count integer not null default 0,
  red_count integer not null default 0,
  recommendations jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, week_start)
);

-- Límite de uso del análisis con IA (lo usa la Edge Function) ---------------------
create table public.ai_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index ai_usage_user_created_idx on public.ai_usage (user_id, created_at desc);

-- Row Level Security ------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.foods enable row level security;
alter table public.meals enable row level security;
alter table public.meal_foods enable row level security;
alter table public.weekly_reports enable row level security;
alter table public.ai_usage enable row level security;

create policy "Perfil propio: leer" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "Perfil propio: actualizar" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "Catálogo: lectura" on public.foods
  for select to authenticated using (true);

create policy "Comidas propias" on public.meals
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Alimentos de comidas propias" on public.meal_foods
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.meals m where m.id = meal_id and m.user_id = (select auth.uid()))
  );

create policy "Reportes propios" on public.weekly_reports
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ai_usage no tiene políticas: solo la Edge Function (service role) escribe en ella.

-- Storage: fotos privadas por usuario ---------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meal-photos', 'meal-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "Fotos propias: leer" on storage.objects
  for select to authenticated
  using (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Fotos propias: subir" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Fotos propias: actualizar" on storage.objects
  for update to authenticated
  using (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Fotos propias: borrar" on storage.objects
  for delete to authenticated
  using (bucket_id = 'meal-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
