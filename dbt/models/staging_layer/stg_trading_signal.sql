{{
  config(
    materialized = 'view'
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'TRADING_SIGNALS')  }}
