{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'coingecko']
  )
}}

SELECT * FROM {{ source('coingecko_source', 'COINGECKO_TOKEN_CATEGORIES') }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
