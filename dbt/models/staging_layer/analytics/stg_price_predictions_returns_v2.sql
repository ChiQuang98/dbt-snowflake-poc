{{
  config(
    materialized = 'view',
    tags = ['staging_layer']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'PRICE_PREDICTIONS_RETURNS_V2')  }}
