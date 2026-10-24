with order_checks as (

    select
        count(*) as total_orders,

        count(*) filter (
            where order_id is null
        ) as missing_order_ids,

        count(*) filter (
            where order_purchase_timestamp is null
        ) as missing_purchase_timestamps,

        count(*) filter (
            where order_status = 'delivered'
              and order_delivered_customer_date is null
        ) as delivered_missing_delivery_date,

        count(*) filter (
            where order_delivered_carrier_date is not null
              and order_purchase_timestamp is not null
              and order_delivered_carrier_date
                  < order_purchase_timestamp
        ) as carrier_before_purchase,

        count(*) filter (
            where order_delivered_customer_date is not null
              and order_delivered_carrier_date is not null
              and order_delivered_customer_date
                  < order_delivered_carrier_date
        ) as customer_before_carrier

    from {{ ref('fct_orders') }}

),

payment_checks as (

    select
        count(*) as total_payment_rows,

        count(*) filter (
            where order_id is null
        ) as missing_payment_order_ids,

        count(*) filter (
            where payment_value is null
        ) as missing_payment_values,

        count(*) filter (
            where payment_value < 0
        ) as negative_payment_values,

        count(*) filter (
            where payment_installments < 1
        ) as invalid_installments

    from {{ source('raw_olist', 'raw_payments') }}

),

orphan_payments as (

    select
        count(*) as orphan_payment_rows

    from {{ source('raw_olist', 'raw_payments') }} p

    left join {{ source('raw_olist', 'raw_orders') }} o
        on p.order_id = o.order_id

    where o.order_id is null

),

metrics as (

    select
        'order_completeness'::text as check_name,
        'missing_order_ids'::text as metric_name,
        missing_order_ids::numeric as metric_value,
        total_orders::numeric as reference_count
    from order_checks

    union all

    select
        'order_completeness',
        'missing_purchase_timestamps',
        missing_purchase_timestamps::numeric,
        total_orders::numeric
    from order_checks

    union all

    select
        'order_completeness',
        'delivered_missing_delivery_date',
        delivered_missing_delivery_date::numeric,
        total_orders::numeric
    from order_checks

    union all

    select
        'logistics_quality',
        'carrier_before_purchase',
        carrier_before_purchase::numeric,
        total_orders::numeric
    from order_checks

    union all

    select
        'logistics_quality',
        'customer_before_carrier',
        customer_before_carrier::numeric,
        total_orders::numeric
    from order_checks

    union all

    select
        'payment_integrity',
        'missing_payment_order_ids',
        missing_payment_order_ids::numeric,
        total_payment_rows::numeric
    from payment_checks

    union all

    select
        'payment_integrity',
        'missing_payment_values',
        missing_payment_values::numeric,
        total_payment_rows::numeric
    from payment_checks

    union all

    select
        'payment_integrity',
        'negative_payment_values',
        negative_payment_values::numeric,
        total_payment_rows::numeric
    from payment_checks

    union all

    select
        'payment_integrity',
        'invalid_installments',
        invalid_installments::numeric,
        total_payment_rows::numeric
    from payment_checks

    union all

    select
        'payment_integrity',
        'orphan_payment_rows',
        orphan_payment_rows::numeric,
        total_payment_rows::numeric
    from payment_checks
    cross join orphan_payments
)

select
    check_name,
    metric_name,
    metric_value,
    reference_count,

    case
        when reference_count > 0
        then round(
            100.0 * metric_value / reference_count,
            4
        )
        else null
    end as metric_pct,

    case
        when metric_value = 0 then 'PASS'
        when metric_name in (
            'delivered_missing_delivery_date',
            'carrier_before_purchase',
            'customer_before_carrier',
            'invalid_installments'
        ) then 'WARN'
        else 'FAIL'
    end as health_status,

    current_timestamp as evaluated_at

from metrics