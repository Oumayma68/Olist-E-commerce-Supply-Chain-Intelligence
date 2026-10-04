with source as (

    select *
    from {{ source('raw_olist', 'raw_products') }}

    {% if target.name == 'dev' %}
        limit 1000
    {% endif %}

)

select
    product_id,
    nullif(trim(product_category_name), '') as product_category_name,
    product_name_lenght as product_name_length,
    product_description_lenght as product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
from source
