{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'tm_reference']
  )
}}

SELECT * FROM {{ source('tm_reference_defillama_source', 'AGGREGATED_TOKENS_TVL') }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
