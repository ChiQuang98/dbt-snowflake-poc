{{
  config(
    materialized = 'incremental',
    unique_key = ['TOKEN_ID','DATE'],
    cluster_by = ['TOKEN_ID','DATE'],
    tags = ['DATA_HUB_LAYER','hourly']
  )
}}

-- quant grade
with quant_gr as (
    with last_quant as (
        select 
            *,lag(quant_grade) over (partition by token_id order by date asc) as quant_grade_lag,
        from {{ ref('stg_quant_grades_v2') }}
    )
    select  
            token_id,
            date,
            round(quant_grade, 2) as quant_grade,
            case when quant_grade_lag > 0 then round((quant_grade - quant_grade_lag) / quant_grade_lag * 100, 2) else null end 
            as quant_grade_24h_pct_change,
            cumulative_return as all_time_return,
            max_drawdown,
            cagr,
            sharpe,
            sortino,
            volatility,
            skew,
            kurtosis,
            daily_value_at_risk,
            expected_shortfall_cvar,
            profit_factor,
            tail_ratio,
            daily_return_avg,
            daily_return_std,
        from
            last_quant
),
-- ta grade
ta_gr as (
    with last_ta as (select *,
                        lag(ta_grade) over (partition by token_id order by date asc) as ta_grade_lag,
                        from {{ ref('stg_ta_grades') }})
    select
            token_id, 
            date,
            round(ta_grade, 2) as ta_grade,
            case when ta_grade_lag > 0 then round((ta_grade - ta_grade_lag) / ta_grade_lag * 100, 2) else null end 
            as ta_grade_24h_pct_change
        from
            last_ta
),
-- TM trader grade
tm_trader_grade as (
    select
        token_id,
        date,
        tm_trader_grade,
        case when tm_trader_grade_lag > 0 then round((tm_trader_grade - tm_trader_grade_lag) / tm_trader_grade_lag * 100, 2) else null end as tm_trader_grade_24h_pct_change
        from (
            select token_id, date, round(tm_grade, 2) as tm_trader_grade, lag(tm_grade, 1, 0) over (partition by token_id order by date) tm_trader_grade_lag 
            from {{ ref('stg_tm_grades') }}
        )
),
-- trading signals
trading_signals as (
    select 
        token_id, 
        date,
        signal as trading_signal, 
        last_signal as TOKEN_TREND,
        round(strategy_cumulative_roi, 4) as trading_signals_returns,
        round(holding_cumulative_roi, 4) as holding_returns
    from {{ ref('stg_technical_combined_indicator') }}
),

-- price prediction
predictions as (
    with pivot_pred as (
        select t1.token_id, t1.date, t2.date as forecast_date, t2.forecast, t2.forecast_lower, t2.forecast_upper from {{ ref('stg_price_predictions_v2') }} t1 
        inner join {{ ref('stg_price_predictions_v2') }} t2 on t1.token_id = t2.token_id and t2.date between (t1.date + 1) and (t1.date + 7) where t1.date <= current_date()
    )
    select
        token_id,
        date,
        object_agg(
            case
                when rn = 1 then '1-day-forecast'
                when rn = 2 then '2-day-forecast'
                when rn = 3 then '3-day-forecast'
                when rn = 4 then '4-day-forecast'
                when rn = 5 then '5-day-forecast'
                when rn = 6 then '6-day-forecast'
                when rn = 7 then '7-day-forecast'
            end,
            OBJECT_CONSTRUCT_KEEP_NULL(
                'forecast', forecast,
                'forecast_upper', forecast_upper,
                'forecast_lower', forecast_lower
             )
        ) AS forecasts_for_next_7_days
    from (
        select
            token_id,
            date,
            forecast,
            forecast_lower,
            forecast_upper,
            row_number() over (partition by token_id, date order by forecast_date) as rn
            from pivot_pred
        )
    where rn <= 7 group by token_id, date
),
-- full preductions with returns
pred_returns as (
    select token_id, date, forecasts_for_next_7_days, predicted_returns_7d 
    from predictions 
    inner join 
    (
        select token_id, date, round(predicted_return, 4) as predicted_returns_7d 
        from {{ ref('stg_price_predictions_returns_v2') }}
    ) using (token_id, date)
),
-- exchange list
exch as 
(
    select token_id, array_agg(object_construct('exchange_id', exchange, 'exchange_name', name)) as exchange_list 
    from {{ ref('stg_coingecko_token_exchanges') }} group by token_id
),
-- category list
categ as (
    select 
        token_id, array_agg(object_construct('category_id', cat.id, 'category_slug', cat.category_id, 'category_name', cat.name)) as category_list 
    from {{ ref('stg_coingecko_token_categories') }} tokens inner join {{ ref('stg_coingecko_categories') }} cat
    on tokens.category_id = cat.id group by token_id
),
-- token name and symbol and meta
tokens as (
    with app_url as (
        select value from {{ ref('stg_app_config') }} where key = 'APP_URL'
    )
    select 
        token_id, 
        name as token_name, 
        token_symbol, cg_id,
        concat(value, cg_id) as token_url, 
        is_stablecoin 
    from {{ ref('stg_coingecko_tokens') }} 
    JOIN APP_URL
    where status = 'ACTIVE'
)
-- main select
select * 
    from tokens
left join exch using (token_id)
left join categ using (token_id)
inner join (
    select * from tm_trader_grade
    full outer join ta_gr using (token_id, date)
    full outer join quant_gr using (token_id, date)
    full outer join trading_signals using (token_id, date)
    full outer join pred_returns using (token_id, date)
) using (token_id)
where DATE >= '2021-01-01' and DATE < current_date()
-- union with latest data 
union all 
select 
    token_id,
    token_name, 
    token_symbol, 
    cg_id, 
    token_url, 
    is_stablecoin,
    exchange_list, 
    category_list, 
    date, 
    tm_trader_grade,
    tm_trader_grade_24h_pct_change, 
    ta_grade, 
    ta_grade_24h_pct_change, 
    quant_grade, 
    quant_grade_24h_pct_change,
    all_time_return, 
    max_drawdown, 
    cagr, 
    sharpe, 
    sortino,
    volatility, 
    skew, 
    kurtosis, 
    daily_value_at_risk,
    expected_shortfall_cvar, 
    profit_factor, 
    tail_ratio,
    daily_return_avg, 
    daily_return_std, 
    trading_signal, 
    TOKEN_TREND,
    trading_signals_returns, 
    holding_returns,
    forecasts_for_next_7_days, 
    predicted_returns_7d 
from {{ ref('crypto_trader_hub_current') }}

{% if is_incremental() %}
    where date >= (select max(date) from {{ this }})
{% endif %}
