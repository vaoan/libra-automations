-- DEV ONLY: fake seller, buyer and product, then one order that goes
-- pending -> pending_verification. Fires order.created and order.status_changed.
-- Run against Libra's local database: scripts/test-order.sh

insert into public.user_profiles (id, email, display_name)
values ('00000000-0000-4000-a000-000000000001', 'seller@example.com', 'Tienda de prueba'),
       ('00000000-0000-4000-a000-000000000002', 'buyer@example.com', 'Comprador de prueba')
on conflict (id) do nothing;

insert into public.products (id, slug, name_en, name_es, type, price, currency, seller_id)
values ('00000000-0000-4000-b000-000000000001', 'n8n-test-sticker-pack', 'Sticker pack', 'Paquete de stickers',
        'merch', 25000, 'COP', '00000000-0000-4000-a000-000000000001')
on conflict (id) do nothing;

begin;
with new_order as (
  insert into public.orders (user_id, seller_id, total, currency, payment_status)
  values ('00000000-0000-4000-a000-000000000002', '00000000-0000-4000-a000-000000000001', 50000, 'COP', 'awaiting_payment')
  returning id
)
insert into public.order_items (order_id, product_id, quantity, unit_price, currency)
select id, '00000000-0000-4000-b000-000000000001', 2, 25000, 'COP' from new_order;
commit;

select pg_sleep(3);

update public.orders
set payment_status = 'pending_verification', transfer_number = 'TEST-123456'
where id = (select id from public.orders where seller_id = '00000000-0000-4000-a000-000000000001' order by created_at desc limit 1);
