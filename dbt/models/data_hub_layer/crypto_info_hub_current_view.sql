{{
  config(
    materialized = 'view',
    tags = ['DATA_HUB_LAYER','hourly'],
    post_hook = [
        "grant select on {{ this }} to role chat_bot;"
    ]
  )
}}

with prices as (
    select
        token_id,
        current_price::float as current_price,
        total_volume::float as volume_24h,
        case when market_cap=0 then null else market_cap::float end as market_cap,
        case when market_cap_rank=0 then null else market_cap_rank::int end as market_cap_rank,
        MARKET_CAP_CHANGE_PERCENTAGE_24H::float as market_cap_24h_pct_change,
        circulating_supply::int as circulating_supply,
        total_supply::int as total_supply,
        max_supply::int as max_supply,
        case
            when (
                fully_diluted_valuation = 0
                AND total_supply = 0
            ) THEN market_cap::float
            when fully_diluted_valuation = 0 THEN (current_price * total_supply)::float
            ELSE fully_diluted_valuation::float
        END AS fully_diluted_valuation,
        high_24h::float as high_24h,
        low_24h::float as low_24h,
        round(price_change_percentage_1h_in_currency::number(38, 5), 2) as price_pct_change_1h,
        round(price_change_percentage_24h::number(38, 5), 3) as price_pct_change_24h,
        round(price_change_percentage_7D_in_currency::number(38, 5), 2) as price_pct_change_7d,
        round(price_change_percentage_30d_in_currency::number(38, 5), 2) as price_pct_change_30d,
        round(price_change_percentage_200d_in_currency::number(38, 5), 2) as price_pct_change_200d,
        round(price_change_percentage_1y_in_currency::number(38, 5), 2) as price_pct_change_1y
    from
        {{ ref('stg_coingecko_token_live_price_latest') }}
)
select
    crypto_analytics_hub_current.*,
    current_price,
    volume_24h,
    market_cap,
    market_cap_rank,
	market_cap_24h_pct_change,
    circulating_supply,
    total_supply,
    max_supply,
    fully_diluted_valuation,
    high_24h,
    low_24h,
    OBJECT_CONSTRUCT_KEEP_NULL(
    '1h',
    round(price_pct_change_1h, 2),
    '24h',
    round(price_pct_change_24h, 3),
    '7d',
    round(price_pct_change_7d, 2),
    '30d',
    round(price_pct_change_30d, 2),
    '200d',
    round(price_pct_change_200d, 2),
    '1y',
    round(price_pct_change_1y, 2),
    'all_time',
    round((ALL_TIME_RETURN * 100), 2)) as price_change_percentage
from {{ ref('crypto_analytics_hub_current') }} 
left join prices using (token_id)
