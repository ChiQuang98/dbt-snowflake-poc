{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'tm_analytics']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'FUNDAMENTAL_GRADES')  }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
