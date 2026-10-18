select
    oi.order_id
from {{ ref('fct_order_items') }} as oi
left join {{ ref('fct_orders') }} as o
    on oi.order_id = o.order_id
where o.order_id is null
