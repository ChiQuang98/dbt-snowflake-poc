{{
  config(
    materialized = 'view',
    tags = ['staging_layer']
  )
}}

SELECT * FROM {{ source('tm_reference_source', 'CHAINS_TVL_VIEW') }}
