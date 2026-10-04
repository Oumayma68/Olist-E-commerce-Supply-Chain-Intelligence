with source as (

    select *
    from {{ source('raw_olist', 'raw_order_items') }}

    {% if target.name == 'dev' %}
        limit 1000
    {% endif %}

)

select
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
from source
