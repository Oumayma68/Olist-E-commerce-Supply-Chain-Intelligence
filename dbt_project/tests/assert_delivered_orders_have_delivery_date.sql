{{ config(severity='warn') }}

select *
from {{ ref('fct_orders') }}
where order_status = 'delivered'
  and order_delivered_customer_date is null
