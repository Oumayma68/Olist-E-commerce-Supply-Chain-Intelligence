{{ config(severity='warn') }}

SELECT
    order_id,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM {{ source('raw_olist', 'raw_orders') }}
WHERE order_delivered_customer_date < order_delivered_carrier_date
