-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements. See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License. You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

with portfolio_base as (
    select
        snapshot_date,
        tenant_id,
        office_id,
        product_id,
        currency_code,
        loan_id,
        principal_outstanding,
        total_outstanding,
        is_npa,
        is_watch_list,
        is_par_30,
        is_par_60,
        is_par_90,
        standard_par_band,
        bucket_key,
        bucket_name
    from {{ ref('fact_loan_snapshot') }}
),
portfolio_totals as (
    select
        snapshot_date,
        tenant_id,
        office_id,
        product_id,
        currency_code,

        count(distinct loan_id)                                                     as total_loan_count,
        sum(principal_outstanding)                                                  as total_portfolio_amount,

        sum(case when is_watch_list
                then principal_outstanding else 0 end)                              as watch_list_amount,
        sum(case when is_par_30 and not is_par_60
                then principal_outstanding else 0 end)                              as par_30_59_amount,
        sum(case when is_par_60 and not is_par_90
                then principal_outstanding else 0 end)                              as par_60_89_amount,
        sum(case when is_par_90
                then principal_outstanding else 0 end)                              as par_90_plus_amount,

        sum(case when is_par_30
                then principal_outstanding else 0 end)                              as par_30_amount,
        sum(case when is_par_60
                then principal_outstanding else 0 end)                              as par_60_amount,
        sum(case when is_par_90
                then principal_outstanding else 0 end)                              as par_90_amount,

        sum(case when is_npa
                then principal_outstanding else 0 end)                              as npa_amount,
        sum(case when not is_par_30 and not is_watch_list
                then principal_outstanding else 0 end)                              as current_amount,

        count(distinct case when is_watch_list  then loan_id end)                   as watch_list_loan_count,
        count(distinct case when is_par_30      then loan_id end)                   as par_30_loan_count,
        count(distinct case when is_par_60      then loan_id end)                   as par_60_loan_count,
        count(distinct case when is_par_90      then loan_id end)                   as par_90_loan_count,
        count(distinct case when is_npa         then loan_id end)                   as npa_loan_count,
        count(distinct case when not is_par_30 and not is_watch_list
                            then loan_id end)                                        as current_loan_count
    from portfolio_base
    group by 1, 2, 3, 4, 5
),
bucket_distribution as (
    select
        pb.snapshot_date,
        pb.tenant_id,
        pb.office_id,
        pb.product_id,
        pb.currency_code,
        pb.bucket_key,
        pb.bucket_name,
        count(distinct pb.loan_id)              as bucket_loan_count,
        sum(pb.principal_outstanding)           as bucket_outstanding_amount
    from portfolio_base pb
    group by 1, 2, 3, 4, 5, 6, 7
),
enriched_buckets as (
    select
        bd.snapshot_date,
        bd.tenant_id,
        bd.office_id,
        o.office_name,
        bd.product_id,
        p.product_name,
        bd.currency_code,
        bd.bucket_key,
        bd.bucket_name,
        bd.bucket_loan_count,
        bd.bucket_outstanding_amount,

        pt.total_loan_count,
        pt.total_portfolio_amount,
        pt.watch_list_amount,
        pt.par_30_59_amount,
        pt.par_60_89_amount,
        pt.par_90_plus_amount,
        pt.par_30_amount,
        pt.par_60_amount,
        pt.par_90_amount,
        pt.npa_amount,
        pt.current_amount,
        pt.watch_list_loan_count,
        pt.par_30_loan_count,
        pt.par_60_loan_count,
        pt.par_90_loan_count,
        pt.npa_loan_count,
        pt.current_loan_count,

        {{ safe_divide('pt.par_30_amount',  'pt.total_portfolio_amount') }}             as par_30_ratio,
        {{ safe_divide('pt.par_60_amount',  'pt.total_portfolio_amount') }}             as par_60_ratio,
        {{ safe_divide('pt.par_90_amount',  'pt.total_portfolio_amount') }}             as par_90_ratio,
        {{ safe_divide('pt.npa_amount',     'pt.total_portfolio_amount') }}             as npa_ratio,
        {{ safe_divide('pt.par_30_loan_count::numeric', 'pt.total_loan_count::numeric') }} as par_30_rate,
        {{ safe_divide('pt.par_60_loan_count::numeric', 'pt.total_loan_count::numeric') }} as par_60_rate,
        {{ safe_divide('pt.par_90_loan_count::numeric', 'pt.total_loan_count::numeric') }} as par_90_rate,
        {{ safe_divide('pt.total_portfolio_amount',     'pt.total_loan_count::numeric') }} as average_loan_outstanding
    from bucket_distribution bd
    inner join portfolio_totals pt
        on  bd.snapshot_date   = pt.snapshot_date
        and bd.tenant_id       = pt.tenant_id
        and bd.office_id       = pt.office_id
        and bd.product_id      = pt.product_id
        and bd.currency_code   = pt.currency_code
    inner join {{ ref('dim_office') }} o
        on bd.office_id = o.office_id
    inner join {{ ref('dim_product') }} p
        on bd.product_id = p.product_id
),
portfolio_rollup as (
    select
        pt.snapshot_date,
        pt.tenant_id,
        pt.office_id,
        o.office_name,
        pt.product_id,
        p.product_name,
        pt.currency_code,
        -1::bigint                              as bucket_key,
        'All Portfolio'                         as bucket_name,
        pt.total_loan_count                     as bucket_loan_count,
        pt.total_portfolio_amount               as bucket_outstanding_amount,

        pt.total_loan_count,
        pt.total_portfolio_amount,
        pt.watch_list_amount,
        pt.par_30_59_amount,
        pt.par_60_89_amount,
        pt.par_90_plus_amount,
        pt.par_30_amount,
        pt.par_60_amount,
        pt.par_90_amount,
        pt.npa_amount,
        pt.current_amount,
        pt.watch_list_loan_count,
        pt.par_30_loan_count,
        pt.par_60_loan_count,
        pt.par_90_loan_count,
        pt.npa_loan_count,
        pt.current_loan_count,

        {{ safe_divide('pt.par_30_amount',  'pt.total_portfolio_amount') }}             as par_30_ratio,
        {{ safe_divide('pt.par_60_amount',  'pt.total_portfolio_amount') }}             as par_60_ratio,
        {{ safe_divide('pt.par_90_amount',  'pt.total_portfolio_amount') }}             as par_90_ratio,
        {{ safe_divide('pt.npa_amount',     'pt.total_portfolio_amount') }}             as npa_ratio,
        {{ safe_divide('pt.par_30_loan_count::numeric', 'pt.total_loan_count::numeric') }} as par_30_rate,
        {{ safe_divide('pt.par_60_loan_count::numeric', 'pt.total_loan_count::numeric') }} as par_60_rate,
        {{ safe_divide('pt.par_90_loan_count::numeric', 'pt.total_loan_count::numeric') }} as par_90_rate,
        {{ safe_divide('pt.total_portfolio_amount',     'pt.total_loan_count::numeric') }} as average_loan_outstanding
    from portfolio_totals pt
    inner join {{ ref('dim_office') }} o
        on pt.office_id = o.office_id
    inner join {{ ref('dim_product') }} p
        on pt.product_id = p.product_id
)

select * from portfolio_rollup
union all
select * from enriched_buckets
