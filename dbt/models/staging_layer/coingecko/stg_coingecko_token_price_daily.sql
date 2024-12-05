{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'coingecko']
  )
}}

SELECT * FROM {{ source('coingecko_source', 'COINGECKO_ALL_PRICE_DATA_VIEW') }}
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY TOKEN_ID, DATE ORDER BY DATE DESC) = 1

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
