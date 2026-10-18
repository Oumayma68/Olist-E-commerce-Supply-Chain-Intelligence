{{ config(materialized='table') }}

with payments as (

    select *
    from {{ ref('stg_payments') }}

),

payments_enriched as (

    select
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        payment_value,

        -- Payment value in euros
        payment_value as payment_amount,

        -- Flag for installment payments
        case
            when payment_installments > 1 then true
            else false
        end as is_installment_payment

    from payments

)

select *
from payments_enriched
