{{ config(materialized='table') }}

with order_kpis as (

    select
        count(*) as total_orders,

        count(*) filter (
            where order_status = 'delivered'
        ) as delivered_orders,

        count(*) filter (
            where delivery_performance = 'late'
        ) as late_delivered_orders,

        round(
            avg(delivery_delay_days) filter (
                where order_status = 'delivered'
            )::numeric,
            2
        ) as avg_delivery_delay_days,

        round(
            100.0 * count(*) filter (
                where delivery_performance = 'late'
            ) / nullif(
                count(*) filter (
                    where delivery_performance in ('late', 'on_time')
                ),
                0
            ),
            2
        ) as late_delivery_rate_pct

    from {{ ref('fct_orders') }}

),

item_kpis as (

    select
        round(sum(item_revenue)::numeric, 2) as total_item_revenue,
        round(sum(item_freight_cost)::numeric, 2) as total_freight_cost,

        round(
            100.0 * sum(item_freight_cost)
            / nullif(sum(item_revenue), 0),
            2
        ) as freight_to_item_revenue_pct

    from {{ ref('fct_order_items') }}

)

select
    order_kpis.*,
    item_kpis.*
from order_kpis
cross join item_kpis
