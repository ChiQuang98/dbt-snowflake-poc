{{
  config(
    materialized = 'incremental',
    unique_key = ['TOKEN_ID','DATE'],
    cluster_by = ['TOKEN_ID','DATE'],
    tags = ['DATA_HUB_LAYER','hourly']
  )
}}

WITH coingecko_ohlcv_daily_incremental AS (
    SELECT * FROM {{ ref('stg_coingecko_ohlcv_daily') }}

    {% if is_incremental() %}
        WHERE DATE >= (SELECT MAX(DATE) FROM {{ this }})
    {% endif %}

), coingecko_token_price_daily_incremental AS (
    SELECT * FROM {{ ref('stg_coingecko_token_price_daily') }}

    {% if is_incremental() %}
        WHERE DATE >= (SELECT MAX(DATE) FROM {{ this }})
    {% endif %}

), tm_grades_incremental AS (
    SELECT * FROM {{ ref('stg_tm_grades') }}

    {% if is_incremental() %}
        WHERE DATE >= (SELECT MAX(DATE) FROM {{ this }})
    {% endif %}

), technical_combined_indicator_incremental AS (
    SELECT * FROM {{ ref('stg_technical_combined_indicator') }}

    {% if is_incremental() %}
        WHERE DATE >= (SELECT MAX(DATE) FROM {{ this }})
    {% endif %}

), tm_investor_grades_incremental AS (
    SELECT * FROM {{ ref('stg_tm_investor_grades') }}

    {% if is_incremental() %}
        WHERE DATE >= (SELECT MAX(DATE) FROM {{ this }})
    {% endif %}

), price_predictions_v2_incremental AS (
    SELECT * FROM {{ ref('stg_price_predictions_v2') }}

    {% if is_incremental() %}
        WHERE DATE >= (SELECT MAX(DATE) FROM {{ this }})
    {% endif %}

), resistance_support_incremental AS (
    SELECT * FROM {{ ref('stg_resistance_support') }}

    {% if is_incremental() %}
        WHERE DATE >= (SELECT MAX(DATE) FROM {{ this }})
    {% endif %}
)
-- Query to get data for TM Combined chart
SELECT
	DATE,
	TOKEN_ID,
	TOKENS.NAME,
	TOKEN_SYMBOL,
	TOKENS.CG_ID,
    OHLCV.OPEN,
    OHLCV.HIGH,
    OHLCV.LOW,
	OHLCV.CLOSE,
	OHLCV.VOLUME,
	PRICES.PRICE,
    PRICES.MARKET_CAP,
    PRICES.FULLY_DILUTED_VALUATION,
    PRICES.CIRCULATING_SUPPLY,
	GRADE.TM_GRADE,
    INV_GRADE.TM_INVESTOR_GRADE,
	SIGNAL.SIGNAL,
	SIGNAL.LAST_SIGNAL,
	SIGNAL.HOLDING_CUMULATIVE_ROI,
	SIGNAL.STRATEGY_CUMULATIVE_ROI,
    PRED.FORECAST,
    PRED.FORECAST_UPPER,
    PRED.FORECAST_LOWER,
    RES_SUS.LEVEL as RESISTANCE_SUPPORT_LEVEL
FROM
	coingecko_ohlcv_daily_incremental AS OHLCV
    -- joining market data
    LEFT OUTER JOIN coingecko_token_price_daily_incremental AS PRICES using (token_id, date)
	-- joining on grades
	LEFT OUTER JOIN tm_grades_incremental AS GRADE using (token_id, date)
	-- joining on combined indicator signals
	LEFT OUTER JOIN technical_combined_indicator_incremental AS SIGNAL using (token_id, date)
    -- joining investor grade
    LEFT OUTER JOIN tm_investor_grades_incremental AS INV_GRADE using(token_id, date)
    -- joining price predictions
    LEFT OUTER JOIN price_predictions_v2_incremental AS PRED using(token_id, date)
    -- joining historical resistance and support levels
    LEFT OUTER JOIN resistance_support_incremental AS RES_SUS using(token_id, date)
    -- joining proper symbol, cg_id and name
    LEFT OUTER JOIN {{ ref('stg_coingecko_tokens') }} AS TOKENS using(token_id)
{% if is_incremental() %}
    WHERE DATE >= (SELECT MAX(DATE)  FROM {{ this }})
{% endif %}
