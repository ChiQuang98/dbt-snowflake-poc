{{
  config(
    materialized = 'view',
    tags = ['staging_layer']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'TM_GRADES')  }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY TOKEN_ID, DATE ORDER BY DATE DESC) = 1

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
