with source as (

    select *
    from {{ source('raw_olist', 'raw_orders') }}

    {% if target.name == 'dev' %}
        limit 1000
    {% endif %}

)

select
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
from source
