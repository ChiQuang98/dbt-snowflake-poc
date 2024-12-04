{{
  config(
    materialized = 'view',
    tags = ['staging_layer']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'RISK_REWARD_RATIO')  }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
