-- Storage buckets and policies. Private user-media; public product-images.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('user-media', 'user-media', false, 10485760, array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm'])
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "user media read own folder" on storage.objects;
create policy "user media read own folder" on storage.objects for select to authenticated
using (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "user media upload own folder" on storage.objects;
create policy "user media upload own folder" on storage.objects for insert to authenticated
with check (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "user media update own folder" on storage.objects;
create policy "user media update own folder" on storage.objects for update to authenticated
using (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "user media delete own folder" on storage.objects;
create policy "user media delete own folder" on storage.objects for delete to authenticated
using (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "public product images read" on storage.objects;
create policy "public product images read" on storage.objects for select to anon, authenticated
using (bucket_id = 'product-images');
drop policy if exists "admins upload product images" on storage.objects;
create policy "admins upload product images" on storage.objects for insert to authenticated
with check (bucket_id = 'product-images' and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists "admins update product images" on storage.objects;
create policy "admins update product images" on storage.objects for update to authenticated
using (bucket_id = 'product-images' and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'))
with check (bucket_id = 'product-images' and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists "admins delete product images" on storage.objects;
create policy "admins delete product images" on storage.objects for delete to authenticated
using (bucket_id = 'product-images' and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
