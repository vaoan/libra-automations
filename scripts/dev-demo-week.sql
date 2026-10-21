-- DEV ONLY: shape the fake orders from test-order.sh into a realistic week so the
-- reminder and the weekly report have something to show. Only touches orders of
-- the fake seller (00000000-0000-4000-a000-000000000001).

-- Approve the two oldest receipts through Libra's own transition function.
select public.update_order_status(id, 'approved', 'Aprobado en la demo')
from (
  select id from public.orders
  where seller_id = '00000000-0000-4000-a000-000000000001' and payment_status = 'pending_verification'
  order by created_at
  limit 2
) as to_approve;

-- Make the newest receipt expire in 10 hours (inside the reminder's 24 h window).
update public.orders
set expires_at = now() + interval '10 hours'
where id = (
  select id from public.orders
  where seller_id = '00000000-0000-4000-a000-000000000001' and payment_status = 'pending_verification'
  order by created_at desc
  limit 1
);

select payment_status, count(*) from public.orders
where seller_id = '00000000-0000-4000-a000-000000000001'
group by payment_status order by payment_status;
