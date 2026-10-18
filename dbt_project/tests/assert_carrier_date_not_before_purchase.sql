{{ config(severity='warn') }}

SELECT
    order_id,
    order_purchase_timestamp,
    order_delivered_carrier_date
FROM {{ source('raw_olist', 'raw_orders') }}
WHERE order_delivered_carrier_date < order_purchase_timestamp
