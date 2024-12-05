{{
  config(
    materialized = 'table',
    cluster_by = ['TOKEN_ID','TIMESTAMP'],
    tags = ['DATA_HUB_LAYER','hourly'],
    post_hook = [
      "GRANT SELECT ON {{ this }} TO ROLE CHAT_BOT;"
    ]
  )
}}

with raw_market as (
        select 
            token_id, 
            volume, 
            fully_diluted_valuation, 
            circulating_supply, 
            lag(volume) over (partition by token_id order by date asc) as volume_previous,
            lag(fully_diluted_valuation) over (partition by token_id order by date asc) as fully_diluted_valuation_previous,
            lag(circulating_supply) over (partition by token_id order by date asc) as circulating_supply_previous,
        from {{ ref('stg_coingecko_token_price_daily') }} qualify date = max(date) over ()
), last_market as (
    select
        token_id,
        case 
            when volume_previous > 0 then (volume - volume_previous) / volume_previous 
        else null end volume_24h_pct_change,
        case 
            when fully_diluted_valuation_previous > 0 then (fully_diluted_valuation - fully_diluted_valuation_previous) / fully_diluted_valuation_previous 
        else null end fdv_24h_pct_change,
        case 
            when circulating_supply_previous > 0 then (circulating_supply - circulating_supply_previous) / circulating_supply_previous 
        else null end circulating_supply_24h_pct_change
    from raw_market
),
-- token start date
token_start_date as (
    select
        token_id,
        min(date) as LAUNCH_DATE
    from {{ ref('stg_coingecko_token_price_daily') }}
    group by token_id
)
select  
    coalesce(trader.date, investor.date) as date,
	date_trunc(hour, current_timestamp) as timestamp,
	TOKEN_ID,
    coalesce(trader.token_name, investor.token_name) as TOKEN_NAME,
    coalesce(trader.TOKEN_SYMBOL, investor.TOKEN_SYMBOL) as TOKEN_SYMBOL,
    coalesce(trader.cg_id, investor.cg_id) as cg_id,
    coalesce(trader.TOKEN_URL, investor.TOKEN_URL) as TOKEN_URL,
    coalesce(trader.IS_STABLECOIN, investor.IS_STABLECOIN) as IS_STABLECOIN,
    coalesce(trader.summary, investor.summary) as summary,
    coalesce(trader.images, investor.images) as images,
    coalesce(trader.platforms, investor.platforms) as platforms,
    coalesce(trader.explorer, investor.explorer) as explorer,
    coalesce(trader.all_time_high, investor.all_time_high) as all_time_high,
    coalesce(trader.all_time_low, investor.all_time_low) as all_time_low,
    LAUNCH_DATE,
	TM_TRADER_GRADE,
	TM_TRADER_GRADE_24H_PCT_CHANGE,
	TM_TRADER_GRADE_HOURLY,
	TM_TRADER_GRADE_HOURLY_1H_PCT_CHANGE,
	TA_GRADE,
    TA_GRADE_24H_PCT_CHANGE,
	QUANT_GRADE,
	QUANT_GRADE_24H_PCT_CHANGE,
    TM_INVESTOR_GRADE,
	TM_INVESTOR_GRADE_7D_PCT_CHANGE,
	FUNDAMENTAL_GRADE,
    FUNDAMENTAL_GRADE_7D_PCT_CHANGE,
	TECHNOLOGY_GRADE,
    TECHNOLOGY_GRADE_7D_PCT_CHANGE,
	VALUATION_GRADE,
    VALUATION_GRADE_7D_PCT_CHANGE,
	VALUATION_METRICS,
	ALL_TIME_RETURN,
	MAX_DRAWDOWN,
	CAGR,
	SHARPE,
	SORTINO,
	VOLATILITY,
	SKEW,
	KURTOSIS,
	DAILY_VALUE_AT_RISK,
	EXPECTED_SHORTFALL_CVAR,
	PROFIT_FACTOR,
	TAIL_RATIO,
	DAILY_RETURN_AVG,
	DAILY_RETURN_STD,
    TVL,
    TVL_PERCENT_CHANGE,
	TRADING_SIGNAL,
    LAST_TRADING_SIGNAL,
	TOKEN_TREND,
	TRADING_SIGNALS_RETURNS,
	HOLDING_RETURNS,
	TRADING_SIGNAL_HOURLY,
	LAST_TRADING_SIGNAL_HOURLY,
	TOKEN_TREND_HOURLY,
	TRADING_SIGNALS_RETURNS_HOURLY,
	HOLDING_RETURNS_HOURLY,
	FORECASTS_FOR_NEXT_7_DAYS,
	PREDICTED_RETURNS_7D,
	SCENARIO_PREDICTION,
    LIQUIDITY_METRICS,
    LIQUIDITYPOOLS,
    CREATOR_METRICS,
    HOLDER_METRICS,
    DEFI_SCANNER_METRICS,
	HISTORICAL_RESISTANCE_SUPPORT_LEVELS,
	CURRENT_RESISTANCE_LEVEL,
	CURRENT_SUPPORT_LEVEL,
	RISK_REWARD_RATIO,
	CURRENT_DOMINANCE,
	SCENARIO_ANALYSIS,
	TOP_CORRELATION,
    LIQUIDITY_ISSUES,
    HOLDER_ISSUES,
    FUNDAMENTAL_ISSUES,
	DEFI_USAGE_SCORE,
	COMMUNITY_SCORE,
	EXCHANGE_SCORE,
	VC_SCORE,
	ONCHAIN_SCORE,
	TOKENOMICS_SCORE,
	REDDIT_METRICS,
	TWITTER_METRICS,
	TELEGRAM_METRICS,
    WEBSITE_METRICS,
	FUNDRAISING_METRICS,
	DEFI_SCANNER_SCORE,	
	SECURITY_SCORE, 
    ACTIVITY_SCORE, 
    REPOSITORY_SCORE, 
    COLLABORATION_SCORE,
    TECHNOLOGY_ISSUES,
	GITHUB_METRICS,
    coalesce(trader.exchange_list, investor.exchange_list) as exchange_list,
    coalesce(trader.category_list, investor.category_list) as category_list,
	volume_24h_pct_change,
    fdv_24h_pct_change,
    circulating_supply_24h_pct_change
from {{ ref('crypto_investor_hub_current') }} investor 
full outer join {{ ref('crypto_trader_hub_current') }} trader using (token_id)
left join last_market using(token_id) left join token_start_date using(token_id)