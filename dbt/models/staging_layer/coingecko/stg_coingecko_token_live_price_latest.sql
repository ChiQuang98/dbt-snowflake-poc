{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'coingecko']
  )
}}

SELECT * FROM {{ source('coingecko_source', 'COINGECKO_TOKENS_LIVE_PRICE_FRONT') }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}