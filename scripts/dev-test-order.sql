-- DEV ONLY: fake seller, buyer and product used by scripts/test-order.sh.
insert into public.user_profiles (id, email, display_name)
values ('00000000-0000-4000-a000-000000000001', 'seller@example.com', 'Tienda de prueba'),
       ('00000000-0000-4000-a000-000000000002', 'buyer@example.com', 'Comprador de prueba')
on conflict (id) do nothing;

insert into public.products (id, slug, name_en, name_es, type, price, currency, seller_id)
values ('00000000-0000-4000-b000-000000000001', 'n8n-test-sticker-pack', 'Sticker pack', 'Paquete de stickers',
        'merch', 25000, 'COP', '00000000-0000-4000-a000-000000000001')
on conflict (id) do nothing;
