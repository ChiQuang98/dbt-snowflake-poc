{{
  config(
    materialized = 'view'
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'TRADER_GRADE_V3') }}
