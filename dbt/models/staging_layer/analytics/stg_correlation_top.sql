{{
  config(
    materialized = 'view',
    tags = ['staging_layer']
  )
}}

SELECT * FROM {{ source('tm_analytics_source', 'CORRELATION_TOP')  }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 3
{% endif %}

