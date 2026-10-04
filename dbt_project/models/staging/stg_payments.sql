with source as (

    select *
    from {{ source('raw_olist', 'raw_payments') }}

    {% if target.name == 'dev' %}
        limit 1000
    {% endif %}

)

select
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
from source
