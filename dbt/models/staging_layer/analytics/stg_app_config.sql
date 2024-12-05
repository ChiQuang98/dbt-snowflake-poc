{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'tm_analytics']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'APP_CONFIG')  }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 3
{% endif %}

