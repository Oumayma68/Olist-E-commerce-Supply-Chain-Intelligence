{{ config(materialized='table') }}

select
    product_id,
    product_category_name,
    product_name_lenght as product_name_length,
    product_description_lenght as product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,

    dbt_scd_id,
    dbt_valid_from,
    dbt_valid_to,

    (dbt_valid_to is null) as is_current

from {{ source('snap_olist', 'snp_products') }}
