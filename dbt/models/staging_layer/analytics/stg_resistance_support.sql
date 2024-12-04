{{
  config(
    materialized = 'view',
    tags = ['staging_layer']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'RESISTANCE_SUPPORT')  }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY TOKEN_ID, DATE ORDER BY DATE DESC) = 1
