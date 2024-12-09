{{
  config(
    materialized = 'table',
    cluster_by = ['TOKEN_ID','DATE'],
    tags = ['DATA_HUB_LAYER','hourly']
  )
}}

-- quant grade
with quant_gr as (
    with last_quant as (
        select 
            *,
            lag(quant_grade) over (partition by token_id order by date asc) as quant_grade_lag,
        from {{ ref('stg_quant_grades_v2') }}
        qualify date = max(date) over ()
    )
    select  
        token_id,
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
    with last_ta as (
        select *,
            lag(ta_grade) over (partition by token_id order by date asc) as ta_grade_lag,
        from {{ ref('stg_ta_grades') }}
        qualify date = max(date) over ()
    )
    select
        token_id, 
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
    tm_trader_grade,
    case when tm_trader_grade_lag > 0 then round((tm_trader_grade - tm_trader_grade_lag) / tm_trader_grade_lag * 100, 2) else null end as tm_trader_grade_24h_pct_change
    from (
        select token_id, date, round(tm_grade, 2) as tm_trader_grade, lag(tm_grade, 1, 0) over (partition by token_id order by date) tm_trader_grade_lag 
        from {{ ref('stg_tm_grades') }}
    )
    qualify date = max(date) over ()
),
-- TM trader grade hourly
tm_trader_grade_hourly as (
select
    token_id,
    tm_trader_grade_hourly,
    case when tm_trader_grade_hourly_lag > 0 then round((tm_trader_grade_hourly - tm_trader_grade_hourly_lag) / tm_trader_grade_hourly_lag * 100, 2) else null end as tm_trader_grade_hourly_1h_pct_change
    from (
        select 
            token_id, timestamp, round(tm_trader_grade, 2) as tm_trader_grade_hourly, 
            lag(tm_trader_grade, 1, 0) over (partition by token_id order by timestamp) tm_trader_grade_hourly_lag 
        from {{ ref('stg_tm_trader_grade_v2') }}
    )
    qualify timestamp = max(timestamp) over ()
),
-- trading signals
trading_signals_daily as (
    with signals_data as (
        select 
            token_id, 
            signal as trading_signal, 
            last_signal as token_trend,
            round(strategy_cumulative_roi, 4) as trading_signals_returns,
            round(holding_cumulative_roi, 4) as holding_returns
        from {{ ref('stg_technical_combined_indicator') }}
        qualify date = max(date) over ()
    ), last_signals as (
        SELECT 
            token_id, signal as last_signal, to_timestamp(date) as last_signal_timestamp, strategy_cumulative_roi as last_signal_cumulative_roi
        from {{ ref('stg_technical_combined_indicator') }}
        where signal != 0
        qualify date = max(date) over (partition by token_id)
    )
    select 
        token_id, 
        trading_signal, 
        token_trend, 
        OBJECT_CONSTRUCT_KEEP_NULL(
            'value', last_signal, 'timestamp', last_signal_timestamp, 'returns_since_last_signal', (1 + trading_signals_returns) / (1 + last_signal_cumulative_roi) - 1
        ) as last_trading_signal,
        trading_signals_returns, 
        holding_returns,
    from signals_data 
    full outer join last_signals 
    using(token_id)
),
-- trading signals hourly
trading_signals_hourly as (
    with signals_data_hourly as (
        select
            token_id,
            timestamp,
            signal as trading_signal_hourly,
            2 * position - 1 as token_trend_hourly,
            round(strategy_cum_roi, 4) as trading_signals_returns_hourly,
            round(holding_cum_roi, 4) as holding_returns_hourly
    from
        {{ ref('stg_trading_signals') }}
    qualify timestamp = max(timestamp) over()
    ), last_signals_hourly as (
        SELECT
            token_id,
            signal as last_signal,
            timestamp as last_signal_timestamp,
            strategy_cum_roi as last_signal_cumulative_roi
        from
            {{ ref('stg_trading_signals') }}
        where signal != 0 
        qualify timestamp = max(timestamp) over (partition by token_id)
    )
    select
        s.token_id,
        s.trading_signal_hourly,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'value', l.last_signal,
            'timestamp', l.last_signal_timestamp,
            'returns_since_last_signal', (1 + s.trading_signals_returns_hourly) / (1 + l.last_signal_cumulative_roi) - 1
        ) as last_trading_signal_hourly,
        s.token_trend_hourly,
        s.trading_signals_returns_hourly,
        s.holding_returns_hourly
    from
        signals_data_hourly s
    inner join last_signals_hourly l using(token_id)
),
-- price prediction
predictions as (
    SELECT
    token_id,
    OBJECT_AGG(
      CASE
        WHEN rn = 1 THEN '1-day-forecast'
        WHEN rn = 2 THEN '2-day-forecast'
        WHEN rn = 3 THEN '3-day-forecast'
        WHEN rn = 4 THEN '4-day-forecast'
        WHEN rn = 5 THEN '5-day-forecast'
        WHEN rn = 6 THEN '6-day-forecast'
        WHEN rn = 7 THEN '7-day-forecast'
      END,
      OBJECT_CONSTRUCT_KEEP_NULL(
        'forecast', forecast,
        'forecast_upper', forecast_upper,
        'forecast_lower', forecast_lower
      )
    ) AS forecasts_for_next_7_days
    FROM (
        SELECT
            token_id,
            name,
            date,
            forecast,
            forecast_lower,
            forecast_upper,
            ROW_NUMBER() OVER (PARTITION BY token_id ORDER BY date) AS rn
        FROM {{ ref('stg_price_predictions_v2') }}
        WHERE date > CURRENT_DATE()
    )
    WHERE rn <= 7
    GROUP BY token_id
),
-- full preductions with returns
pred_returns as (
    select 
        token_id, 
        forecasts_for_next_7_days, 
        predicted_returns_7d 
    from predictions 
    inner join 
    (
        select token_id, round(predicted_return, 4) as predicted_returns_7d 
        from {{ ref('stg_price_predictions_returns_v2') }}
        qualify date = max(date) over ()
    ) 
    using (token_id)
),
-- scenario price prediction
scenario_prediction as (
    select 
        token_id,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'predicted_date',
            ANY_VALUE(predicted_date),
            'category_name',
            ANY_VALUE(category_name),
            'current_price',
            ANY_VALUE(current_price),
            'token_mcap',
            ANY_VALUE(token_mcap),
            'self_past_performance',
            ANY_VALUE(self_past_performance),
            'avg_past_performance',
            ANY_VALUE(avg_past_performance),
            'similar_tokens_info',
            ANY_VALUE(similar_tokens_info),
            'total_mcap',
            ANY_VALUE(total_mcap),
            'scenario_prediction',
            array_agg(OBJECT_CONSTRUCT_KEEP_NULL(
                'scenario',
                scenario,
                'total_mcap_scenario',
                total_mcap_scenario,
                'predicted_price_moon',
                predicted_price_moon,
                'predicted_roi_moon',
                predicted_roi_moon,
                'predicted_mcap_moon',
                predicted_mcap_moon,
                'predicted_fdv_moon',
                predicted_fdv_moon,
                'predicted_price_base',
                predicted_price_base,
                'predicted_roi_base',
                predicted_roi_base,
                'predicted_mcap_base',
                predicted_mcap_base,
                'predicted_fdv_base',
                predicted_fdv_base,
                'predicted_price_bear',
                predicted_price_bear,
                'predicted_roi_bear',
                predicted_roi_bear,
                'predicted_mcap_bear',
                predicted_mcap_bear,
                'predicted_fdv_bear',
                predicted_fdv_bear
                )
            )
        ) as scenario_prediction
    from {{ ref('stg_price_predictions_v3') }} 
    where date = (select max(date) from {{ ref('stg_price_predictions_v3') }}) group by token_id
),
-- resistance support
res_sup as (
    select  
        token_id, 
        array_agg(OBJECT_CONSTRUCT_KEEP_NULL('date', date, 'level', level)) 
        within group (order by date asc) as historical_resistance_support_levels
    from {{ ref('stg_resistance_support') }} 
    group by token_id
),
-- risk reward ratio
risk_reward as (
    select 
        token_id, 
        resistance as current_resistance_level, 
        support as current_support_level, 
        risk_reward_ratio 
    from {{ ref('stg_risk_reward_ratio') }}
),
-- scenario analysis
scen_analysis as (
    select 
        token_id, 
        max(current_dominance) as current_dominance, 
        array_agg(
        OBJECT_CONSTRUCT_KEEP_NULL(
            'crypto_market_cap_trillion',
            total_market_cap,
            'token_dominance',
            dominance,
            'price_prediction',
            prediction
        )) as scenario_analysis
    from {{ ref('stg_scenario_analysis') }} 
    group by token_id
),
-- correlation
correl as (
    select 
        token_id_1 as token_id, 
        array_agg(
            OBJECT_CONSTRUCT_KEEP_NULL(
                'token',
                token_name_2,
                'correlation',
                correlation::number(8, 3)
            )) as top_correlation
    from {{ ref('stg_correlation_top') }} 
    group by token_id_1
),
-- tvl
tvl as (
    with latest_token_tvl as
    (
        select token_id, tvl, tvl_percent_change
        from {{ ref('stg_aggregated_tokens_tvl') }}
        qualify date = max(date) over()
    ),
    latest_chain_tvl as (
        select token_id, tvl, tvl_percent_change 
        from {{ ref('stg_chains_tvl') }}
        qualify date = max(date) over()
    )
    select 
        token_id, tvl, tvl_percent_change from latest_token_tvl 
    where not exists (
        select 1 from latest_chain_tvl where latest_chain_tvl.token_id = latest_token_tvl.token_id
        )
    union all 
    select * from latest_chain_tvl
),
-- exchange list
exch as (
    select 
        token_id, 
        array_agg(
            object_construct('exchange_id', exchange, 'exchange_name', name)
        ) as exchange_list 
    from {{ ref('stg_coingecko_token_exchanges') }}
    group by token_id
),
-- category list
categ as (
    select 
    token_id, 
    array_agg(
            object_construct('category_id', cat.id, 'category_slug', cat.category_id, 'category_name', cat.name)
        ) as category_list 
    from {{ ref('stg_coingecko_token_categories') }} tokens 
    inner join {{ ref('stg_coingecko_categories') }} cat
    on tokens.category_id = cat.id 
    group by token_id
),
-- token name and symbol and meta
tokens as (
    with app_url as (
        select value 
        from {{ ref('stg_app_config') }} 
        where key = 'APP_URL'
    )
    select 
        token_id, 
        name as token_name, 
        token_symbol, 
        cg_id, 
        concat(value, cg_id) as token_url, 
        is_stablecoin, 
        summary, 
        images,
        CASE
            WHEN platforms = PARSE_JSON('{ "": "" }') THEN PARSE_JSON('{}')
            WHEN platforms = PARSE_JSON('{ "": null }') then PARSE_JSON('{}')
            WHEN platforms is NULL then PARSE_JSON('{}')
            ELSE platforms
        END as platforms,
        explorer,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'ath',
            all_time_high::float,
            'ath_date',
            all_time_high_date::date,
            'ath_change_percentage',
            ath_change_percentage::float
        ) as all_time_high,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'atl',
            all_time_low::float,
            'atl_date',
            all_time_low_date::date,
            'atl_change_percentage',
            atl_change_percentage::float
        ) as all_time_low
    from {{ ref('stg_coingecko_tokens') }}
    JOIN APP_URL
    where status = 'ACTIVE'
)

-- main select
select 
    current_date() as date,
    date_trunc(hour, current_timestamp) as timestamp,
    * 
from 
    tokens
left join 
    exch using (token_id)
left join 
    categ using (token_id)
left join (
    select * from tm_trader_grade
    full outer join tm_trader_grade_hourly using (token_id)
    full outer join ta_gr using (token_id)
    full outer join quant_gr using (token_id)
    full outer join trading_signals_daily using (token_id)
    full outer join trading_signals_hourly using (token_id)
    full outer join pred_returns using (token_id)
    full outer join scenario_prediction using (token_id)
    full outer join res_sup using (token_id)
    full outer join risk_reward using (token_id)
    full outer join scen_analysis using (token_id)
    full outer join correl using (token_id)
    full outer join tvl using(token_id)
) using (token_id)