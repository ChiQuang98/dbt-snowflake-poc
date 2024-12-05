{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'tm_analytics']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'PRICE_PREDICTIONS_RETURNS_V2')  }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
