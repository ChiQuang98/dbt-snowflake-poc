{{
  config(
    materialized = 'table',
    cluster_by = ['TOKEN_ID','TIMESTAMP'],
    tags = ['DATA_HUB_LAYER','hourly']
  )
}}

-- github metrics
with github_metrics as (
    with last_github as (
        select *, 
            lag(contributors) over (partition by token_id order by date asc) as contributors_previous,
            lag(watchers) over (partition by token_id order by date asc) as watchers_previous,
            lag(total_commits) over (partition by token_id order by date asc) as total_commits_previous,
            lag(closed_issues) over (partition by token_id order by date asc) as closed_issues_previous,
        from {{ ref('stg_github_stats') }} qualify date = max(date) over ()
    )
    select
        token_id,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'organization_name',
            org_name,
            'github_url',
            concat('https://github.com/', org_name),
            'total_commits',
            total_commits,
            'total_commits_15d_change',
            total_commits - total_commits_previous,
            'total_forks',
            total_forks,
            'pull_requests',
            pull_requests,
            'contributors',
            contributors,
            'contributors_15d_change',
            contributors - contributors_previous,
            'watchers',
            watchers,
            'watchers_15d_change',
            watchers - watchers_previous,
            'pulls',
            pulls,
            'closed_issues',
            closed_issues,
            'closed_issues_15d_change',
            closed_issues - closed_issues_previous,
            'open_issues',
            open_issues,
            'total_issues',
            closed_issues + open_issues,
            'stars',
            stars,
            'last_commit_date',
            last_commit_date,
            'languages',
            languages
        ) as github_metrics
    from
        last_github
),

-- technology grades
technology_metrics as (
    with last_tech as (
        select *,
            lag(technology_grade, 7) over (partition by token_id order by date asc) as technology_grade_lag,
        from {{ ref('stg_technology_grades') }} qualify date = max(date) over ()
    )
    select
        token_id,
        round(defi_scanner_score, 2) as defi_scanner_score,
        round(security_score, 2) as security_score,
        round(activity_score, 2) as activity_score,
        round(repository_score, 2) as repository_score,
        round(collaboration_score, 2) as collaboration_score,
        technology_grade,
        case when technology_grade_lag > 0 then round((technology_grade - technology_grade_lag) / technology_grade_lag * 100, 2)
        else null end as technology_grade_7d_pct_change
    from
        last_tech
),
-- technology central
technology_central as (
    select
        *
    from
        technology_metrics
    full outer join github_metrics using (token_id)
),
-- Reddit
reddit_metrics as (
    with last_reddit as (
        select *,
            lag(subscribers) over (partition by token_id order by date asc) as subscribers_previous
        from {{ ref('stg_crypto_subreddit_stats') }} qualify date = max(date) over ()
    )
    select
        token_id,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'subreddit',
            concat('http://reddit.com/r/', subreddit),
            'subscribers_count',
            subscribers::int,
            'subscribers_count_7d_change',
            subscribers::int - subscribers_previous::int
    ) as reddit_metrics
    from
        last_reddit 
),
-- Telegram
telegram_metrics as (
    with last_telegram as (
        select *,
            lag(member_count) over (partition by token_id order by date asc) as member_count_previous
        from {{ ref('stg_crypto_telegram_stats') }} qualify date = max(date) over ()
    )
    select
        token_id,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'telegram_channel',
            concat('https://telegram.me/', telegram),
            'members_count',
            member_count::int,
            'members_count_7d_change',
            member_count::int - member_count_previous::int
        ) as telegram_metrics
    from
        last_telegram
),

-- Twitter
twitter_metrics as (
    with last_twitter as (
        select *,
            lag(followers_count) over (partition by token_id order by date asc) as followers_count_previous,
            lag(tweet_count) over (partition by token_id order by date asc) as tweet_count_previous
        from {{ ref('stg_crypto_twitter_stats') }} qualify date = max(date) over ()
    )
select
    token_id,
    OBJECT_CONSTRUCT_KEEP_NULL(
            'twitter_url',
            concat('twitter.com/', username),
            'followers_count',
            followers_count::int,
            'followers_count_7d_change',
            followers_count::int - followers_count_previous::int,
            'following_count',
            following_count::int,
            'tweet_count',
            tweet_count::int,
            'tweet_count_7d_change',
            tweet_count::int - tweet_count_previous::int,
            'listed_count',
            listed_count::int,
            'verified',
            verified::boolean
        ) as twitter_metrics
    from
        last_twitter
),

-- Website
website_metrics as (
    with last_seo as (
        select *,
            lag(org_traffic) over (partition by token_id order by date asc) as org_traffic_previous,
            case 
                when org_traffic_previous > 0 then                              
                round((org_traffic - org_traffic_previous) / org_traffic_previous, 4)
                else null end as org_traffic_7d_pct_change
        from {{ ref('stg_crypto_website_stats') }} qualify date = max(date) over ()
    )
    select
        token_id,
        OBJECT_CONSTRUCT_KEEP_NULL(
                'website',
                website,
                'domain_rating',
                domain_rating,
                'org_traffic',
                org_traffic,
                'org_traffic_7d_change',
                org_traffic - org_traffic_previous,
                'org_traffic_7d_pct_change',
                org_traffic_7d_pct_change,
                'paid_traffic',
                paid_traffic,
                'org_keywords',
                org_keywords::int,
                'org_keywords_1_3',
                org_keywords_1_3::int,
                'paid_keywords',
                paid_keywords::int,
                'ahrefs_rank',
                ahrefs_rank
            ) as website_metrics
        from
            last_seo
),

-- Investors metrics
investors_metrics as (
    select
        token_id,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'total_value_raised',
            total_value_raised::int,
            'number_of_rounds',
            number_of_rounds::int,
            'last_round_date',
            last_round_date::date,
            'last_round_type',
            last_round_type::varchar,
            'unique_investors',
            unique_investors::array,
            'rounds_data',
            rounds_data
        ) as fundraising_metrics
    from
        {{ ref('stg_crypto_fundraising_stats') }}
),

-- fundamental scores and grade
fundamental_metrics as (
    with last_fund as (
        select token_id, fundamental_grade,
            lag(fundamental_grade, 7) over (partition by token_id order by date asc) as fundamental_grade_lag,
        from {{ ref('stg_fundamental_grades') }} qualify date = max(date) over()
    ),
    last_community as (
        select token_id, community_score from {{ ref('stg_fundamental_community_score') }} qualify date = max(date) over()
    ),
    last_defi as (
        select token_id, defi_usage_score from {{ ref('stg_fundamental_defi_usage_score') }} qualify date = max(date) over()
    ),
    last_tokenomics as (
        select token_id, tokenomics_score from {{ ref('stg_fundamental_tokenomics_score') }} qualify date = max(date) over()
    ),
    last_vc as (
        select token_id, vc_score from {{ ref('stg_fundamental_vc_score') }} qualify date = max(date) over()
    ),
    last_exchange as (
        select token_id, exchange_score from {{ ref('stg_fundamental_exchange_score') }} qualify date = max(date) over()
    ),
    last_onchain as (
        select token_id, onchain_score from {{ ref('stg_fundamental_onchain_score') }} qualify date = max(date) over()
    )
    select
        token_id, 
        community_score,
        defi_usage_score,
        tokenomics_score,
        vc_score,
        exchange_score,
        onchain_score,
        fundamental_grade,
        case when fundamental_grade_lag > 0 then round((fundamental_grade - fundamental_grade_lag) / fundamental_grade_lag * 100, 2)
        else null end as fundamental_grade_7d_pct_change
    from
        last_fund
        full outer join last_community using(token_id)
        full outer join last_defi using(token_id)
        full outer join last_tokenomics using(token_id)
        full outer join last_vc using(token_id)
        full outer join last_exchange using(token_id)
        full outer join last_onchain using(token_id)
),

-- defi scanner data
defi_scanner_details as (
    select token_id, 
        -- FUNDAMENTAL
        OBJECT_CONSTRUCT_KEEP_NULL(
            'totalliquidity',
            totalliquidity,
            'isadequateliquiditypresent',
            isadequateliquiditypresent::boolean,
            'totallockedpercent',
            totallockedpercent,
            'totalunlockedpercent',
            totalunlockedpercent,
            'isenoughliquiditylocked',
            isenoughliquiditylocked::boolean,
            'totalburnedpercent',
            totalburnedpercent,
            'burned',
            burned,
            'burnedpercentage',
            burnedpercentage,
            'tokentotalsupply',
            tokentotalsupply
        ) liquidity_metrics, 
        liquiditypools,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'creator',
            creator,
            'creatorbalancepercentage',
            creatorbalancepercentage,
            'creatorbalance',
            creatorbalance,
            'owner',
            owner,
            'ownerbalance',
            ownerbalance,
            'ownerbalancepercentage',
            ownerbalancepercentage,
            'initialfunder',
            initialfunder,
            'initialfunding',
            initialfunding,
            'firsttxdate',
            firsttxdate
        ) creator_metrics,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'topholderstotalpercentage',
            topholderstotalpercentage,
            'topholders',
            topholders,
            'topholderstotal',
            topholderstotal
        ) holder_metrics,
        fundamental_issues,
        liquidity_issues,
        holder_issues,
        
        -- TECHNOLOGY
        OBJECT_CONSTRUCT_KEEP_NULL(
            'compilerversion',
            compilerversion,
            'outdatedcompiler',
            outdatedcompiler,
            'protocol',
            protocol,
            'whitelisted',
            whitelisted,
            'is_scam',
            is_scam,
            'defi_link',
            defi_link
        ) defi_scanner_metrics,
        technology_issues
    from {{ ref('stg_crypto_defi_stats') }}
),

-- fundamental central
fundamental_central as (
    select
        *
    from
        fundamental_metrics
    full outer join reddit_metrics using (token_id)
    full outer join twitter_metrics using (token_id)
    full outer join telegram_metrics using (token_id)
    full outer join website_metrics using (token_id)
    full outer join investors_metrics using (token_id)
    full outer join defi_scanner_details using(token_id)
),

-- valuation grades
valuation_central as (
    with last_val as (
        select *,
            lag(valuation_grade, 7) over (partition by token_id order by date asc) as valuation_grade_lag,
        from {{ ref('stg_valuation_grades') }} qualify date = max(date) over()
    )
    select
        token_id, 
        valuation_grade,
        case when valuation_grade_lag > 0 then round((valuation_grade - valuation_grade_lag) / valuation_grade_lag * 100, 2)
        else null end as valuation_grade_7d_pct_change,
        OBJECT_CONSTRUCT_KEEP_NULL(
        'fdv',
        fdv::float,
        'category_fdv_median',
        category_fdv_median,
        'project_age',
        project_age::int
        ) as valuation_metrics
    from
        last_val
),

-- investor grades
investor_grades as (
    select
        token_id,
        tm_investor_grade,
    case 
        when tm_investor_grade_lag > 0 then round((tm_investor_grade - tm_investor_grade_lag) / tm_investor_grade_lag * 100, 2)
        else null 
    end as tm_investor_grade_7d_pct_change
    from (
        select token_id, date, round(tm_investor_grade, 2) as tm_investor_grade, lag(tm_investor_grade, 7, 0) over (partition by token_id order by date) tm_investor_grade_lag 
        from {{ ref('stg_tm_investor_grades') }}
    ) qualify date = max(date) over ()
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
from CRYPTO_DB.COINGECKO.COINGECKO_TOKEN_CATEGORIES tokens inner join CRYPTO_DB.COINGECKO.COINGECKO_CATEGORIES cat
on tokens.category_id = cat.id group by token_id),

-- token name and symbol and meta
tokens as (
    with app_url as (
        select value from {{ ref('stg_app_config') }} where key = 'APP_URL'
    )
    select 
        token_id,
        name as token_name,
        token_symbol, 
        cg_id, 
        concat(value, cg_id) as token_url, 
        is_stablecoin, 
        summary, 
        images,
        CASE
            WHEN platforms = PARSE_JSON('{ "": "" }') THEN PARSE_JSON('{}')
        WHEN platforms = PARSE_JSON('{ "": null }') then PARSE_JSON('{}')
        WHEN platforms is NULL then PARSE_JSON('{}')
        ELSE platforms
        END as platforms,
        explorer,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'ath',
            all_time_high::float,
            'ath_date',
            all_time_high_date::date,
            'ath_change_percentage',
            ath_change_percentage::float
        ) as all_time_high,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'atl',
            all_time_low::float,
            'atl_date',
            all_time_low_date::date,
            'atl_change_percentage',
            atl_change_percentage::float
        ) as all_time_low,
        CASE WHEN github_url = '' OR github_url = 'null' THEN NULL
        WHEN not contains(github_url, '[') THEN github_url
        ELSE get(parse_json(github_url), 0) END AS github_url,
        CASE WHEN cg_subreddit_url = '' OR cg_subreddit_url = 'https://www.reddit.com' OR cg_subreddit_url = 'null' THEN NULL
        ELSE cg_subreddit_url END as subreddit,
        CASE WHEN cg_telegram_channel = '' OR cg_telegram_channel = 'null' THEN NULL
        ELSE concat('https://telegram.me/', cg_telegram_channel) END AS telegram_channel,
        CASE WHEN twitter = '' OR twitter = 'null' THEN NULL
        ELSE concat('twitter.com/', twitter) END AS twitter_url,
        CASE WHEN website = '' OR website = 'null' or (contains(website, 'reddit') and not contains(lower(token_name), 'reddit')) THEN NULL
        ELSE website END AS website
    from {{ ref('stg_coingecko_tokens') }}
    join app_url
    where status = 'ACTIVE'
)

-- main select
select 
    current_date() as date,
	date_trunc(hour, current_timestamp) as timestamp,
	tokens.TOKEN_ID,
	TOKEN_NAME,
	TOKEN_SYMBOL,
	CG_ID,
	TOKEN_URL,
	IS_STABLECOIN,
	SUMMARY,
    IMAGES,
	PLATFORMS,
	EXPLORER,
	ALL_TIME_HIGH,
	ALL_TIME_LOW,
	CATEGORY_LIST,
	EXCHANGE_LIST,
	TM_INVESTOR_GRADE,
	TM_INVESTOR_GRADE_7D_PCT_CHANGE,
	COMMUNITY_SCORE,
	DEFI_USAGE_SCORE,
	TOKENOMICS_SCORE,
	VC_SCORE,
	EXCHANGE_SCORE,
    ONCHAIN_SCORE,
	FUNDAMENTAL_GRADE,
	FUNDAMENTAL_GRADE_7D_PCT_CHANGE,
	COALESCE(metrics.reddit_metrics, 
        OBJECT_CONSTRUCT_KEEP_NULL(
            'subreddit', tokens.subreddit
        )) as reddit_metrics,
	COALESCE(metrics.twitter_metrics, 
        OBJECT_CONSTRUCT_KEEP_NULL(
            'twitter_url', tokens.twitter_url
        )) as twitter_metrics,
	COALESCE(metrics.telegram_metrics, 
        OBJECT_CONSTRUCT_KEEP_NULL(
            'telegram_channel', telegram_channel
        )) as telegram_metrics,
	COALESCE(metrics.website_metrics, 
        OBJECT_CONSTRUCT_KEEP_NULL(
            'website', tokens.website
        )) as website_metrics,
	FUNDRAISING_METRICS,
	LIQUIDITY_METRICS,
	LIQUIDITYPOOLS,
	CREATOR_METRICS,
	HOLDER_METRICS,
	FUNDAMENTAL_ISSUES,
	LIQUIDITY_ISSUES,
	HOLDER_ISSUES,
	DEFI_SCANNER_METRICS,
	TECHNOLOGY_ISSUES,
	DEFI_SCANNER_SCORE,
	SECURITY_SCORE,
	ACTIVITY_SCORE,
	REPOSITORY_SCORE,
	COLLABORATION_SCORE,
	TECHNOLOGY_GRADE,
	TECHNOLOGY_GRADE_7D_PCT_CHANGE,
    COALESCE(metrics.github_metrics, 
        OBJECT_CONSTRUCT_KEEP_NULL(
            'github_url', tokens.github_url
        )) as github_metrics,
        VALUATION_GRADE,
	VALUATION_GRADE_7D_PCT_CHANGE,
	VALUATION_METRICS
from 
    tokens
left join categ using (token_id)
left join exch using (token_id)
left join (
    select * from investor_grades
    full outer join fundamental_central using (token_id)
    full outer join technology_central using (token_id)
    full outer join valuation_central using(token_id)
) metrics 
using(token_id)