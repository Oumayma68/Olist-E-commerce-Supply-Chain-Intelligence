{{ config(materialized='table') }}

select
    order_id,
    customer_id,
    order_status,

    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    -- Time between purchase and approval, in hours
    round(
        (
            extract(
                epoch from (
                    order_approved_at - order_purchase_timestamp
                )
            ) / 3600.0
        )::numeric,
        2
    ) as approval_delay_hours,

    -- Time between purchase and customer delivery, in days
    round(
        (
            extract(
                epoch from (
                    order_delivered_customer_date - order_purchase_timestamp
                )
            ) / 86400.0
        )::numeric,
        2
    ) as delivery_delay_days,

    -- Positive = late, negative = early, zero = on time
    round(
        (
            extract(
                epoch from (
                    order_delivered_customer_date - order_estimated_delivery_date
                )
            ) / 86400.0
        )::numeric,
        2
    ) as delivery_vs_estimate_days,
    -- True when delivery occurred after the estimated date
    case
        when order_delivered_customer_date is null
          or order_estimated_delivery_date is null
            then null
        when order_delivered_customer_date > order_estimated_delivery_date
            then true
        else false
    end as is_delivery_late,

    -- Delivery performance category
    case
        when order_delivered_customer_date is null
            then 'not_delivered'
        when order_estimated_delivery_date is null
            then 'estimate_unavailable'
        when order_delivered_customer_date > order_estimated_delivery_date
            then 'late'
        else 'on_time'
    end as delivery_performance    

from {{ ref('stg_orders') }}
