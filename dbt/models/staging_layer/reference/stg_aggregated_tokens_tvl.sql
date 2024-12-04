{{
  config(
    materialized = 'view',
    tags = ['staging_layer']
  )
}}

SELECT * FROM {{ source('tm_reference_source', 'AGGREGATED_TOKENS_TVL') }}
