
{{
  config(
    materialized = 'incremental',
    cluster_by = ['TOKEN_ID','DATE'],
    tags = ['DATA_HUB_LAYER','hourly']
  )
}}

-- technology grades
with technology_metrics as (
    with last_tech as (
        select 
            *,
            lag(technology_grade, 7) over (partition by token_id order by date asc) as technology_grade_lag
        from {{ ref('stg_technology_grades') }} qualify date = max(date) over ()
    )
    select
        token_id,
        date,
        round(defi_scanner_score, 2) as defi_scanner_score,
        round(security_score, 2) as security_score,
        round(activity_score, 2) as activity_score,
        round(repository_score, 2) as repository_score,
        round(collaboration_score, 2) as collaboration_score,
        technology_grade,
        case 
            when technology_grade_lag > 0 then round((technology_grade - technology_grade_lag) / technology_grade_lag * 100, 2)
        else null end as technology_grade_7d_pct_change
    from
        last_tech
),
-- fundamental scores and grade
fundamental_metrics as (
    with last_fund as (
        select 
            token_id, 
            date, 
            fundamental_grade,
            lag(fundamental_grade, 7) over (partition by token_id order by date asc) as fundamental_grade_lag
        from {{ ref('stg_fundamental_grades') }} qualify date = max(date) over ()
    ),
    last_community as (
        select token_id, date, community_score from {{ ref('stg_fundamental_community_score') }}
    ),
    last_defi as (
        select token_id, date, defi_usage_score from {{ ref('stg_fundamental_defi_usage_score') }}
    ),
    last_tokenomics as (
        select token_id, date, tokenomics_score from {{ ref('stg_fundamental_tokenomics_score') }}
    ),
    last_vc as (
        select token_id, date, vc_score from {{ ref('stg_fundamental_vc_score') }}
    ),
    last_exchange as (
        select token_id, date, exchange_score from {{ ref('stg_fundamental_exchange_score') }}
    ),
    last_onchain as (
        select token_id, date, onchain_score from {{ ref('stg_fundamental_onchain_score') }}
    )
    select
        token_id, 
        date,
        community_score,
        defi_usage_score,
        tokenomics_score,
        vc_score,
        exchange_score,
        onchain_score,
        fundamental_grade,
        case 
            when fundamental_grade_lag > 0 then round((fundamental_grade - fundamental_grade_lag) / fundamental_grade_lag * 100, 2)
        else null end as fundamental_grade_7d_pct_change
    from
        last_fund
    full outer join last_community using(token_id, date)
    full outer join last_defi using(token_id, date)
    full outer join last_tokenomics using(token_id, date)
    full outer join last_vc using(token_id, date)
    full outer join last_exchange using(token_id, date)
    full outer join last_onchain using(token_id, date)
),

-- valuation grades
valuation_metrics as (
    with last_val as (
        select 
            *,
            lag(valuation_grade, 7) over (partition by token_id order by date asc) as valuation_grade_lag
        from {{ ref('stg_valuation_grades') }} qualify date = max(date) over ()
    )
    select
        token_id, 
        date,
        valuation_grade,
        case 
            when valuation_grade_lag > 0 then round((valuation_grade - valuation_grade_lag) / valuation_grade_lag * 100, 2)
        else null end as valuation_grade_7d_pct_change        
    from
        last_val
),

-- investor grades
investor_grades as (
    select
        token_id,
        date,
        tm_investor_grade,
        case 
            when tm_investor_grade_lag > 0 then round((tm_investor_grade - tm_investor_grade_lag) / tm_investor_grade_lag * 100, 2)
        else null end as tm_investor_grade_7d_pct_change
    from (
        select 
            token_id,
            date,
            round(tm_investor_grade, 2) as tm_investor_grade,
            lag(tm_investor_grade, 7, 0) over (partition by token_id order by date) tm_investor_grade_lag
        from {{ ref('stg_tm_investor_grades') }}
    )
),

-- exchange list
exch as (
    select 
        token_id, 
        array_agg(object_construct('exchange_id', exchange, 'exchange_name', name)) as exchange_list 
    from {{ ref('stg_coingecko_token_exchanges') }} 
    group by token_id
),

-- category list
categ as (
    select 
        token_id, 
        array_agg(object_construct('category_id', cat.id, 'category_slug', cat.category_id, 'category_name', cat.name)) as category_list 
    from 
        {{ ref('stg_coingecko_token_categories') }} tokens 
    inner join 
        {{ ref('stg_coingecko_categories') }} cat 
    on tokens.category_id = cat.id 
    group by token_id
),

-- token name and symbol and meta
tokens as (
    with app_url as (
        select 
            value 
        from {{ ref('stg_app_config') }} where key = 'APP_URL'
    )
    select 
        token_id, 
        name as token_name, 
        token_symbol, 
        cg_id,
        concat(value, cg_id) as token_url , 
        is_stablecoin, 
    from {{ ref('stg_coingecko_tokens') }} 
    join app_url
    where status = 'ACTIVE'
)

-- main select
select 
    * 
from 
    tokens
left join exch using (token_id)
left join categ using (token_id)
inner join (
    select 
        * 
    from investor_grades
    full outer join fundamental_metrics using (token_id, date)
    full outer join technology_metrics using (token_id, date)
    full outer join valuation_metrics using (token_id, date)
) using(token_id) 
where DATE >= '2021-01-01' and DATE < current_date()
-- union with latest data 
union all 
select 
    token_id, 
    token_name, 
    token_symbol, 
    cg_id, 
    token_url, 
    is_stablecoin,
    exchange_list, 
    category_list, 
    date, 
    tm_investor_grade,
    tm_investor_grade_7d_pct_change, 
    community_score, 
    defi_usage_score, 
    tokenomics_score, 
    vc_score,
    exchange_score, 
    onchain_score, 
    fundamental_grade, 
    fundamental_grade_7d_pct_change, 
    defi_scanner_score, 
    security_score, 
    activity_score, 
    repository_score, 
    collaboration_score, 
    technology_grade, 
    technology_grade_7d_pct_change, 
    valuation_grade, 
    valuation_grade_7d_pct_change 
from {{ ref('crypto_investor_hub_current') }}
