{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'tm_analytics']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'TECHNICAL_COMBINED_INDICATOR')  }}
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY TOKEN_ID, DATE ORDER BY DATE DESC) = 1

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
