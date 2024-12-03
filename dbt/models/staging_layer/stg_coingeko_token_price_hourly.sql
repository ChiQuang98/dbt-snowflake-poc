{{
  config(
    materialized = 'view'
  )
}}

SELECT * FROM {{ source('coingecko_source', 'COINGECKO_TOKEN_PRICE_HOURLY_VIEW') }}
