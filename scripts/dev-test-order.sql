-- DEV ONLY: fake seller, buyer and product used by scripts/test-order.sh.
insert into public.user_profiles (id, email, display_name)
values ('00000000-0000-4000-a000-000000000001', 'seller@example.com', 'Tienda de prueba'),
       ('00000000-0000-4000-a000-000000000002', 'buyer@example.com', 'Comprador de prueba')
on conflict (id) do nothing;

insert into public.products (id, slug, name_en, name_es, type, price, currency, seller_id)
values ('00000000-0000-4000-b000-000000000001', 'n8n-test-sticker-pack', 'Sticker pack', 'Paquete de stickers',
        'merch', 25000, 'COP', '00000000-0000-4000-a000-000000000001')
on conflict (id) do nothing;

-- Payment methods the test seller shows to buyers. The fixtures print "Ahorros ****4321":
-- ...c001 is the seller's real account (matches), ...c002 a different one (wrong-account scenario).
insert into public.seller_payment_methods (id, seller_id, name_en, name_es, display_blocks)
values ('00000000-0000-4000-c000-000000000001', '00000000-0000-4000-a000-000000000001', 'Bank transfer', 'Transferencia',
        '[{"id": "t1", "type": "text", "content_en": "Savings account 001-234-4321, Tienda de prueba", "content_es": "Cuenta de ahorros 001-234-4321 a nombre de Tienda de prueba"}]'),
       ('00000000-0000-4000-c000-000000000002', '00000000-0000-4000-a000-000000000001', 'Nequi', 'Nequi',
        '[{"id": "t1", "type": "text", "content_en": "Nequi 300 555 9999", "content_es": "Nequi 300 555 9999"}]')
on conflict (id) do nothing;
