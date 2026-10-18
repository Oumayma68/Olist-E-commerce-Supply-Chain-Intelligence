select
    p.order_id
from {{ ref('fct_payments') }} as p
left join {{ ref('fct_orders') }} as o
    on p.order_id = o.order_id
where o.order_id is null
