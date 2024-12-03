{{
  config(
    materialized = 'view'
  )
}}

SELECT * FROM {{ source('coingecko_source', 'COINGECKO_TOKENS') }}
