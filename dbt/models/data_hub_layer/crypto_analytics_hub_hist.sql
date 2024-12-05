{{
  config(
    materialized = 'incremental',
    cluster_by = ['TOKEN_ID','DATE'],
    tags = ['DATA_HUB_LAYER','hourly']
  )
}}

select  
    coalesce(trader.date, investor.date) as date,
	TOKEN_ID,
    coalesce(trader.token_name, investor.token_name) as TOKEN_NAME,
    coalesce(trader.TOKEN_SYMBOL, investor.TOKEN_SYMBOL) as TOKEN_SYMBOL,
    coalesce(trader.cg_id, investor.cg_id) as cg_id,
    coalesce(trader.TOKEN_URL, investor.TOKEN_URL) as TOKEN_URL,
    coalesce(trader.IS_STABLECOIN, investor.IS_STABLECOIN) as IS_STABLECOIN,
	TM_TRADER_GRADE,
	TM_TRADER_GRADE_24H_PCT_CHANGE,
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
	TRADING_SIGNAL,
	TOKEN_TREND,
	TRADING_SIGNALS_RETURNS,
	HOLDING_RETURNS,
	FORECASTS_FOR_NEXT_7_DAYS,
	PREDICTED_RETURNS_7D,
	COMMUNITY_SCORE,
	EXCHANGE_SCORE,
    onchain_score,
	VC_SCORE,
	TOKENOMICS_SCORE,
	DEFI_SCANNER_SCORE,	
	SECURITY_SCORE, 
    ACTIVITY_SCORE, 
    REPOSITORY_SCORE, 
    COLLABORATION_SCORE,
    coalesce(trader.exchange_list, investor.exchange_list) as exchange_list,
    coalesce(trader.category_list, investor.category_list) as category_list
from {{ ref('crypto_investor_hub_hist') }} investor 
full outer join {{ ref('crypto_trader_hub_hist') }} trader using (token_id, date)
limit 1

