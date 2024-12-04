{{
  config(
    materialized = 'view',
    tags = ['staging_layer']
  )
}}

SELECT 
{{ dbt_utils.star(from=source('coingecko_source', 'COINGECKO_TOKENS'), except=['id','symbol']) }}
,id as token_id
,UPPER(symbol) as token_symbol
FROM {{ source('coingecko_source', 'COINGECKO_TOKENS') }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}