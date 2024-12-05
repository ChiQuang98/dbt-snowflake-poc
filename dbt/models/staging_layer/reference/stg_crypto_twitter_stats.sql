{{
  config(
    materialized = 'ephemeral',
    tags = ['staging_layer', 'tm_reference']
  )
}}

SELECT * FROM {{ source('tm_reference_twitter_source', 'CRYPTO_TWITTER_STATS') }}

{% if target.name == 'dev' or target.name == 'ci' %}
    limit 2
{% endif %}
