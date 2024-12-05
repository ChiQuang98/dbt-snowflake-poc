{{
  config(
    materialized = 'view',
    tags = ['DATA_HUB_LAYER','hourly']
  )
}}

with latest_market as (
    select
        token_id,
        current_price as price,
        case 
            when market_cap=0 then null 
            else market_cap::float 
        end as market_cap,
        MARKET_CAP_CHANGE_PERCENTAGE_24H::float as market_cap_24h_pct_change,
        circulating_supply::int as circulating_supply,
        case
            when (
                fully_diluted_valuation = 0
                AND total_supply = 0
            ) THEN market_cap::float
            when fully_diluted_valuation = 0 THEN (current_price * total_supply)::float
            ELSE fully_diluted_valuation::float
        END AS fully_diluted_valuation,
    from
        {{ ref('stg_coingecko_token_live_price_latest')}}
), latest_ohlcv as (
    select 
        token_id,
        open, 
        high, 
        low, 
        close, 
        volume 
    from {{ ref('stg_coingecko_ohlcv_daily')}}
    where date = current_date
), historical_chart as (
    select * from {{ ref('tm_combined_chart')}} where date < current_date
), latest_chart as (
    select * from {{ ref('tm_combined_chart')}} where date = current_date
)
select 
    date, 
    token_id,
    name,
    token_symbol,
    cg_id,
    latest_ohlcv.open,
    latest_ohlcv.high,
    latest_ohlcv.low,
    latest_ohlcv.close,
    latest_ohlcv.volume,
    latest_market.price,
    latest_market.market_cap,
    latest_market.fully_diluted_valuation,
    latest_market.circulating_supply,
    tm_grade,
    tm_investor_grade,
    signal,
    last_signal,
    holding_cumulative_roi,
    strategy_cumulative_roi,
    forecast,
    forecast_upper,
    forecast_lower,
    resistance_support_level
from 
    latest_chart 
left join 
    latest_market using (token_id)
left join 
    latest_ohlcv using (token_id)
union all
select 
    * 
from 
    historical_chart
order by date
