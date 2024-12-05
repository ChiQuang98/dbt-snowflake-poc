{{
  config(
    materialized = 'view',
    tags = ['DATA_HUB_LAYER','hourly'],
    post_hook = [
        "grant select on {{ this }} to role chat_bot;"
    ]
  )
}}

select * 
from {{ ref('crypto_info_hub_current_view') }} 
where is_stablecoin!=1 
order by market_cap desc nulls last 
limit 100
