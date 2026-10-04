with source as (

    select *
    from {{ source('raw_olist', 'raw_sellers') }}

    {% if target.name == 'dev' %}
        limit 1000
    {% endif %}

)

select
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
from source
