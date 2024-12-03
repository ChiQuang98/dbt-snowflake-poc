{{
  config(
    materialized = 'view'
  )
}}

SELECT * FROM {{ source('coingecko_source', 'COINGECKO_HOURLY_OHLCV_VIEW') }}
