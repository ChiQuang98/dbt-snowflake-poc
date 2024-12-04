{{
  config(
    materialized = 'incremental',
    unique_key = ['TOKEN_ID','TIMESTAMP'],
    cluster_by = ['TOKEN_ID','TIMESTAMP'],
    tags = ['DATA_HUB_LAYER','hourly']
  )
}}


WITH ohlcv_hourly_incremental AS (
    SELECT * FROM {{ ref('stg_coingecko_ohlcv_hourly') }}
    {% if is_incremental() %}
        WHERE TIMESTAMP >= (SELECT MAX(TIMESTAMP) FROM {{ this }})
    {% endif %}
    {% if target.name == 'dev' %}
        limit 2
    {% endif %}
), token_price_hourly_incremental AS (
    SELECT * FROM {{ ref('stg_coingeko_token_price_hourly') }}
    {% if is_incremental() %}
        WHERE TIMESTAMP >= (SELECT MAX(TIMESTAMP) FROM {{ this }})
    {% endif %}
    {% if target.name == 'dev' %}
        limit 2
    {% endif %}
), trader_grade_v3_incremental AS (
    SELECT * FROM {{ ref('stg_trader_grade_v3') }}
    {% if is_incremental() %}
        WHERE TIMESTAMP >= (SELECT MAX(TIMESTAMP) FROM {{ this }})
    {% endif %}
    {% if target.name == 'dev' %}
        limit 2
    {% endif %}
), trading_signal_incremental AS (
    SELECT * FROM {{ ref('stg_trading_signals') }}
    {% if is_incremental() %}
        WHERE TIMESTAMP >= (SELECT MAX(TIMESTAMP) FROM {{ this }})
    {% endif %}
    {% if target.name == 'dev' %}
        limit 2
    {% endif %}
)
   select 
        TIMESTAMP,
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
        GRADE.TRADER_GRADE,
        SIGNAL.SIGNAL,
        SIGNAL.POSITION,
        SIGNAL.HOLDING_CUM_ROI,
        SIGNAL.STRATEGY_CUM_ROI
    from ohlcv_hourly_incremental AS OHLCV
    -- joining market data
    FULL OUTER JOIN token_price_hourly_incremental AS PRICES USING(token_id, timestamp)
    -- joining grades
    LEFT OUTER JOIN trader_grade_v3_incremental AS GRADE using (token_id, timestamp)
    -- joining on Trading signals
    LEFT OUTER JOIN trading_signal_incremental AS SIGNAL using (token_id, timestamp)
    -- joining proper symbol, cg_id and name
    LEFT OUTER JOIN {{ ref('stg_coingecko_tokens') }} AS TOKENS using(token_id)
    order by timestamp 
{% if target.name == 'dev' %}
    limit 2
{% endif %}
