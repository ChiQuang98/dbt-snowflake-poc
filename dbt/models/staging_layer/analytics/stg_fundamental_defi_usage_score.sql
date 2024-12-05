{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'tm_analytics']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'FUNDAMENTAL_DEFI_USAGE_SCORE')  }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
