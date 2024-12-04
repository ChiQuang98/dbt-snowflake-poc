{{
  config(
    materialized = 'view',
    tags = ['staging_layer']
  )
}}

SELECT * FROM {{ source('tm_reference_source', 'CHAINS_TVL_VIEW') }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
