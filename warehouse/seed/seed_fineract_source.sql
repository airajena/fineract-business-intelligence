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

BEGIN;

DELETE FROM public.m_loan_delinquency_tag_history WHERE loan_id IN (SELECT id FROM public.m_loan WHERE client_id >= 100);
DELETE FROM public.m_loan_transaction               WHERE loan_id IN (SELECT id FROM public.m_loan WHERE client_id >= 100);
DELETE FROM public.m_loan                           WHERE client_id >= 100;
DELETE FROM public.m_client                         WHERE id >= 100;
DELETE FROM public.m_product_loan                   WHERE id >= 100;
DELETE FROM public.m_delinquency_bucket_mappings    WHERE id >= 100;
DELETE FROM public.m_delinquency_range              WHERE id >= 100;
DELETE FROM public.m_delinquency_bucket             WHERE id >= 100;
DELETE FROM public.m_office                         WHERE id >= 100;
DELETE FROM public.batch_job_execution              WHERE job_execution_id = 9001;
DELETE FROM public.batch_job_instance               WHERE job_instance_id  = 9001;

INSERT INTO public.m_office (id, parent_id, hierarchy, external_id, name, opening_date)
VALUES
    (101, 1, '.1.101.', 'OFF-NB', 'North Branch', '2019-04-01'),
    (102, 1, '.1.102.', 'OFF-SB', 'South Branch', '2019-07-01');

INSERT INTO public.m_delinquency_bucket (id, name, created_by, created_on_utc, version, last_modified_by, last_modified_on_utc)
VALUES (101, 'Standard Portfolio Delinquency Bucket', 1, NOW(), 1, 1, NOW());

INSERT INTO public.m_delinquency_range (id, classification, min_age_days, max_age_days, created_by, created_on_utc, version, last_modified_by, last_modified_on_utc)
VALUES
    (101, '1-30 DPD',  1,   30, 1, NOW(), 1, 1, NOW()),
    (102, '31-60 DPD', 31,  60, 1, NOW(), 1, 1, NOW()),
    (103, '61-90 DPD', 61,  90, 1, NOW(), 1, 1, NOW()),
    (104, '90+ DPD',   91, NULL, 1, NOW(), 1, 1, NOW());

INSERT INTO public.m_delinquency_bucket_mappings (id, delinquency_range_id, delinquency_bucket_id, created_by, created_on_utc, version, last_modified_by, last_modified_on_utc)
VALUES
    (101, 101, 101, 1, NOW(), 1, 1, NOW()),
    (102, 102, 101, 1, NOW(), 1, 1, NOW()),
    (103, 103, 101, 1, NOW(), 1, 1, NOW()),
    (104, 104, 101, 1, NOW(), 1, 1, NOW());

INSERT INTO public.m_product_loan (
    id, short_name, currency_code, currency_digits, currency_multiplesof,
    principal_amount, min_principal_amount, max_principal_amount,
    arrearstolerance_amount, name,
    nominal_interest_rate_per_period, annual_nominal_interest_rate,
    interest_method_enum, interest_calculated_in_period_enum,
    repay_every, repayment_period_frequency_enum, number_of_repayments,
    amortization_method_enum, accounting_type,
    overdue_days_for_npa, delinquency_bucket_id,
    loan_transaction_strategy_code, loan_transaction_strategy_name,
    loan_schedule_type, loan_schedule_processing_type,
    repayment_start_date_type_enum
) VALUES
    (101, 'MSME', 'USD', 2, 0,  8000, 500, 50000, 0, 'MSME Loan',
     1.5, 18, 0, 1, 1, 2, 36, 1, 1, 90, 101,
     'mifos-standard-strategy', 'Penalties, Fees, Interest, Principal order',
     'CUMULATIVE', 'HORIZONTAL', 1),
    (102, 'AGRI', 'USD', 2, 0,  5000, 500, 20000, 0, 'Agriculture Loan',
     1.2, 14, 0, 1, 1, 2, 36, 1, 1, 90, 101,
     'mifos-standard-strategy', 'Penalties, Fees, Interest, Principal order',
     'CUMULATIVE', 'HORIZONTAL', 1),
    (103, 'HOUS', 'USD', 2, 0, 15000, 5000, 75000, 0, 'Housing Loan',
     1.0, 12, 0, 1, 1, 2, 60, 1, 1, 90, 101,
     'mifos-standard-strategy', 'Penalties, Fees, Interest, Principal order',
     'CUMULATIVE', 'HORIZONTAL', 1),
    (104, 'EMRG', 'USD', 2, 0,  2000, 300,  5000, 0, 'Emergency Loan',
     2.0, 24, 0, 1, 1, 2, 24, 1, 1, 90, 101,
     'mifos-standard-strategy', 'Penalties, Fees, Interest, Principal order',
     'CUMULATIVE', 'HORIZONTAL', 1);

INSERT INTO public.m_client (
    id, account_no, status_enum, activation_date, office_joining_date,
    office_id, gender_cv_id, date_of_birth, legal_form_enum,
    display_name, submittedon_date,
    created_on_utc, created_by, last_modified_by, last_modified_on_utc
)
SELECT
    100 + s.id,
    'CL' || LPAD((100 + s.id)::text, 6, '0'),
    300,
    '2022-01-01'::date + (s.id * 5)::int,
    '2022-01-01'::date + (s.id * 5)::int,
    CASE WHEN s.id <= 30 THEN 1 WHEN s.id <= 55 THEN 101 ELSE 102 END,
    NULL,
    current_date - ((28 + (s.id % 20)) * 365)::int,
    1,
    'Client ' || (100 + s.id),
    '2022-01-01'::date + (s.id * 5)::int - 3,
    NOW(), 1, 1, NOW()
FROM generate_series(1, 80) AS s(id);

CREATE TEMP TABLE tmp_loan AS
SELECT
    (100 + loan_id)::bigint    AS loan_id,
    (100 + client_id)::bigint  AS client_id,
    office_id::bigint,
    (100 + product_id)::bigint AS product_id,
    principal::numeric(19,6)   AS principal_amount,
    (disburse_date::date + ((loan_id % 8) * 3.5 - 12)::int)::date AS disburse_date,
    (CASE 
        WHEN overdue_days = 110 THEN 90 + (loan_id % 7) * 5 + (client_id % 3)
        WHEN overdue_days = 75  THEN 60 + (loan_id % 5) * 5 + (client_id % 3)
        WHEN overdue_days = 45  THEN 30 + (loan_id % 4) * 4 + (client_id % 3)
        WHEN overdue_days = 20  THEN 10 + (loan_id % 3) * 4 + (client_id % 3)
        ELSE 0
    END)::int                  AS overdue_days,
    term_months::int,
    annual_rate::numeric(10,6)
FROM (VALUES
( 1,  1,   1, 1, 12000, '2025-01-10', 110, 36, 0.18),
( 2,  2,   1, 2,  8000, '2025-01-10', 110, 36, 0.14),
( 3,  3, 101, 1, 10000, '2025-01-10', 110, 36, 0.18),
( 4,  4, 101, 3, 20000, '2025-01-10', 110, 60, 0.12),
( 5,  5, 102, 1, 11000, '2025-01-10', 110, 36, 0.18),
( 6,  6,   1, 2,  7000, '2025-01-10',   0, 36, 0.14),
( 7,  7, 101, 1,  9000, '2025-01-10',   0, 36, 0.18),
( 8,  8, 102, 3, 18000, '2025-01-10',   0, 60, 0.12),
( 9,  9,   1, 1, 13000, '2025-02-10', 110, 36, 0.18),
(10, 10,   1, 2,  8500, '2025-02-10', 110, 36, 0.14),
(11, 11, 101, 3, 22000, '2025-02-10', 110, 60, 0.12),
(12, 12, 102, 1, 10500, '2025-02-10', 110, 36, 0.18),
(13, 13, 102, 2,  7500, '2025-02-10', 110, 36, 0.14),
(14, 14,   1, 1,  9500, '2025-02-10',   0, 36, 0.18),
(15, 15, 101, 2,  6500, '2025-02-10',   0, 36, 0.14),
(16, 16, 102, 3, 17000, '2025-02-10',   0, 60, 0.12),
(17, 17,   1, 1, 12500, '2025-03-10', 110, 36, 0.18),
(18, 18,   1, 2,  8000, '2025-03-10', 110, 36, 0.14),
(19, 19, 101, 3, 21000, '2025-03-10', 110, 60, 0.12),
(20, 20, 102, 1, 10000, '2025-03-10', 110, 36, 0.18),
(21, 21,   1, 1,  9000, '2025-03-10',  75, 36, 0.18),
(22, 22, 101, 2,  7000, '2025-03-10',   0, 36, 0.14),
(23, 23, 102, 3, 19000, '2025-03-10',   0, 60, 0.12),
(24, 24,   1, 1, 11000, '2025-03-10',   0, 36, 0.18),
(25, 25,   1, 1, 13000, '2025-04-10', 110, 36, 0.18),
(26, 26, 101, 2,  8500, '2025-04-10', 110, 36, 0.14),
(27, 27, 101, 3, 23000, '2025-04-10', 110, 60, 0.12),
(28, 28, 102, 1, 10500, '2025-04-10', 110, 36, 0.18),
(29, 29, 102, 1,  9500, '2025-04-10',  75, 36, 0.18),
(30, 30,   1, 2,  7500, '2025-04-10',   0, 36, 0.14),
(31, 31, 101, 3, 20000, '2025-04-10',   0, 60, 0.12),
(32, 32, 102, 1, 12000, '2025-04-10',   0, 36, 0.18),
(33, 33,   1, 1, 12000, '2025-05-10', 110, 36, 0.18),
(34, 34,   1, 2,  8000, '2025-05-10', 110, 36, 0.14),
(35, 35, 101, 3, 22000, '2025-05-10', 110, 60, 0.12),
(36, 36, 102, 1,  9500, '2025-05-10',  75, 36, 0.18),
(37, 37,   1, 1,  8500, '2025-05-10',  75, 36, 0.18),
(38, 38, 101, 2,  7000, '2025-05-10',   0, 36, 0.14),
(39, 39, 102, 3, 19000, '2025-05-10',   0, 60, 0.12),
(40, 40,   1, 1, 11000, '2025-05-10',   0, 36, 0.18),
(41, 41,   1, 1, 13000, '2025-06-10', 110, 36, 0.18),
(42, 42, 101, 2,  8500, '2025-06-10', 110, 36, 0.14),
(43, 43, 102, 3, 24000, '2025-06-10', 110, 60, 0.12),
(44, 44,   1, 1,  9500, '2025-06-10',  75, 36, 0.18),
(45, 45, 101, 1,  8000, '2025-06-10',  75, 36, 0.18),
(46, 46, 102, 2,  7500, '2025-06-10',   0, 36, 0.14),
(47, 47,   1, 3, 21000, '2025-06-10',   0, 60, 0.12),
(48, 48, 101, 1, 12000, '2025-06-10',   0, 36, 0.18),
(49, 49,   1, 1, 12500, '2025-07-10', 110, 36, 0.18),
(50, 50, 101, 2,  8000, '2025-07-10', 110, 36, 0.14),
(51, 51, 102, 3, 23000, '2025-07-10', 110, 60, 0.12),
(52, 52,   1, 1,  9000, '2025-07-10',  75, 36, 0.18),
(53, 53, 101, 1,  7500, '2025-07-10',  45, 36, 0.18),
(54, 54, 102, 2,  7000, '2025-07-10',   0, 36, 0.14),
(55, 55,   1, 3, 20000, '2025-07-10',   0, 60, 0.12),
(56, 56, 101, 1, 11000, '2025-07-10',   0, 36, 0.18),
(57, 57,   1, 1, 11000, '2025-08-10', 110, 36, 0.18),
(58, 58, 101, 2,  7500, '2025-08-10', 110, 36, 0.14),
(59, 59, 102, 3, 22000, '2025-08-10',  75, 60, 0.12),
(60, 60,   1, 1,  9000, '2025-08-10',  75, 36, 0.18),
(61, 61, 101, 1,  7000, '2025-08-10',  45, 36, 0.18),
(62, 62, 102, 2,  6500, '2025-08-10',   0, 36, 0.14),
(63, 63,   1, 3, 19000, '2025-08-10',   0, 60, 0.12),
(64, 64, 101, 1, 10000, '2025-08-10',   0, 36, 0.18),
(65, 65,   1, 1, 12000, '2025-09-10', 110, 36, 0.18),
(66, 66, 101, 2,  8000, '2025-09-10', 110, 36, 0.14),
(67, 67, 102, 3, 21000, '2025-09-10',  75, 60, 0.12),
(68, 68,   1, 1,  8500, '2025-09-10',  45, 36, 0.18),
(69, 69, 101, 1,  7500, '2025-09-10',  45, 36, 0.18),
(70, 70, 102, 2,  7000, '2025-09-10',   0, 36, 0.14),
(71, 71,   1, 3, 20000, '2025-09-10',   0, 60, 0.12),
(72, 72, 101, 1, 11000, '2025-09-10',   0, 36, 0.18),
(73, 73,   1, 1, 12000, '2025-10-10', 110, 36, 0.18),
(74, 74, 101, 2,  8000, '2025-10-10', 110, 36, 0.14),
(75, 75, 102, 3, 22000, '2025-10-10',  75, 60, 0.12),
(76, 76,   1, 1,  9000, '2025-10-10',  45, 36, 0.18),
(77, 77, 101, 1,  8000, '2025-10-10',  45, 36, 0.18),
(78, 78, 102, 2,  7000, '2025-10-10',   0, 36, 0.14),
(79, 79,   1, 3, 20000, '2025-10-10',   0, 60, 0.12),
(80, 80, 101, 1, 11000, '2025-10-10',   0, 36, 0.18),
(81,  1,   1, 1, 13000, '2025-11-10', 110, 36, 0.18),
(82,  2, 101, 3, 23000, '2025-11-10',  75, 60, 0.12),
(83,  3, 102, 2,  8500, '2025-11-10',  75, 36, 0.14),
(84,  4,   1, 1,  9000, '2025-11-10',  45, 36, 0.18),
(85,  5, 101, 1,  8000, '2025-11-10',  45, 36, 0.18),
(86,  6, 102, 2,  7000, '2025-11-10',   0, 36, 0.14),
(87,  7,   1, 3, 21000, '2025-11-10',   0, 60, 0.12),
(88,  8, 101, 1, 12000, '2025-11-10',   0, 36, 0.18),
(89,  9,   1, 1, 12000, '2025-12-10', 110, 36, 0.18),
(90, 10, 101, 3, 22000, '2025-12-10',  75, 60, 0.12),
(91, 11, 102, 2,  8000, '2025-12-10',  75, 36, 0.14),
(92, 12,   1, 1,  9500, '2025-12-10',  45, 36, 0.18),
(93, 13, 101, 1,  8500, '2025-12-10',  45, 36, 0.18),
(94, 14, 102, 2,  7000, '2025-12-10',   0, 36, 0.14),
(95, 15,   1, 3, 20000, '2025-12-10',   0, 60, 0.12),
(96, 16, 101, 1, 11000, '2025-12-10',   0, 36, 0.18),
(97, 17,   1, 1, 12500, '2026-01-10', 110, 36, 0.18),
(98, 18, 101, 3, 21000, '2026-01-10',  75, 60, 0.12),
(99, 19, 102, 1,  9000, '2026-01-10',  45, 36, 0.18),
(100,20,   1, 2,  8000, '2026-01-10',  45, 36, 0.14),
(101,21, 101, 1,  7500, '2026-01-10',  45, 36, 0.18),
(102,22, 102, 2,  7000, '2026-01-10',   0, 36, 0.14),
(103,23,   1, 3, 19000, '2026-01-10',   0, 60, 0.12),
(104,24, 101, 1, 10000, '2026-01-10',   0, 36, 0.18),
(105,25,   1, 3, 22000, '2026-02-10',  75, 60, 0.12),
(106,26, 101, 2,  8500, '2026-02-10',  75, 36, 0.14),
(107,27, 102, 1,  9000, '2026-02-10',  45, 36, 0.18),
(108,28,   1, 1,  8000, '2026-02-10',  45, 36, 0.18),
(109,29, 101, 2,  7500, '2026-02-10',   0, 36, 0.14),
(110,30, 102, 3, 20000, '2026-02-10',   0, 60, 0.12),
(111,31,   1, 1, 11000, '2026-02-10',   0, 36, 0.18),
(112,32, 101, 1, 10000, '2026-02-10',   0, 36, 0.18),
(113,33, 101, 3, 21000, '2026-03-10',  75, 60, 0.12),
(114,34, 102, 1,  9000, '2026-03-10',  45, 36, 0.18),
(115,35,   1, 2,  8000, '2026-03-10',  45, 36, 0.14),
(116,36, 101, 1,  7500, '2026-03-10',  45, 36, 0.18),
(117,37, 102, 2,  7000, '2026-03-10',   0, 36, 0.14),
(118,38,   1, 3, 20000, '2026-03-10',   0, 60, 0.12),
(119,39, 101, 1, 11000, '2026-03-10',   0, 36, 0.18),
(120,40, 102, 1, 10000, '2026-03-10',   0, 36, 0.18),
(121,41,   1, 1,  9500, '2026-04-10',  45, 36, 0.18),
(122,42, 101, 2,  8000, '2026-04-10',  45, 36, 0.14),
(123,43, 102, 1,  7500, '2026-04-10',  45, 36, 0.18),
(124,44,   1, 3, 22000, '2026-04-10',   0, 60, 0.12),
(125,45, 101, 1, 12000, '2026-04-10',   0, 36, 0.18),
(126,46, 102, 2,  8500, '2026-04-10',   0, 36, 0.14),
(127,47,   1, 1, 10000, '2026-04-10',   0, 36, 0.18),
(128,48, 101, 3, 20000, '2026-04-10',   0, 60, 0.12),
(129,49,   1, 1,  9000, '2026-05-10',  45, 36, 0.18),
(130,50, 101, 2,  8000, '2026-05-10',  45, 36, 0.14),
(131,51, 102, 3, 21000, '2026-05-10',   0, 60, 0.12),
(132,52,   1, 1, 12000, '2026-05-10',   0, 36, 0.18),
(133,53, 101, 1, 10000, '2026-05-10',   0, 36, 0.18),
(134,54, 102, 2,  7500, '2026-05-10',   0, 36, 0.14),
(135,55,   1, 3, 19000, '2026-05-10',   0, 60, 0.12),
(136,56, 101, 1, 11000, '2026-05-10',   0, 36, 0.18),
(137,57,   1, 1,  9500, '2026-06-10',  20, 36, 0.18),
(138,58, 101, 2,  8500, '2026-06-10',   0, 36, 0.14),
(139,59, 102, 3, 22000, '2026-06-10',   0, 60, 0.12),
(140,60,   1, 1, 13000, '2026-06-10',   0, 36, 0.18),
(141,61, 101, 1, 11000, '2026-06-10',   0, 36, 0.18),
(142,62, 102, 2,  8000, '2026-06-10',   0, 36, 0.14),
(143,63,   1, 3, 20000, '2026-06-10',   0, 60, 0.12),
(144,64, 101, 1, 10000, '2026-06-10',   0, 36, 0.18)
) AS t(loan_id, client_id, office_id, product_id, principal, disburse_date, overdue_days, term_months, annual_rate);

ALTER TABLE tmp_loan ADD COLUMN vintage_months       int;
ALTER TABLE tmp_loan ADD COLUMN repaid_frac          numeric(10,8);
ALTER TABLE tmp_loan ADD COLUMN principal_repaid      numeric(19,6);
ALTER TABLE tmp_loan ADD COLUMN principal_outstanding numeric(19,6);
ALTER TABLE tmp_loan ADD COLUMN interest_charged      numeric(19,6);
ALTER TABLE tmp_loan ADD COLUMN interest_repaid       numeric(19,6);
ALTER TABLE tmp_loan ADD COLUMN interest_outstanding  numeric(19,6);
ALTER TABLE tmp_loan ADD COLUMN total_outstanding     numeric(19,6);
ALTER TABLE tmp_loan ADD COLUMN mature_date           date;

UPDATE tmp_loan SET
    vintage_months = GREATEST(
        EXTRACT(YEAR FROM AGE(current_date, disburse_date))::int * 12
        + EXTRACT(MONTH FROM AGE(current_date, disburse_date))::int,
        1
    );

UPDATE tmp_loan SET
    repaid_frac = LEAST(vintage_months::numeric / term_months, 0.90)
                  * CASE WHEN overdue_days > 0 THEN 0.40 ELSE 1.0 END,
    mature_date = disburse_date + (term_months * 30)::int;

UPDATE tmp_loan SET
    principal_repaid      = ROUND(principal_amount * repaid_frac, 6),
    principal_outstanding = ROUND(principal_amount * (1 - repaid_frac), 6),
    interest_charged      = ROUND(principal_amount * annual_rate, 6),
    interest_repaid       = ROUND(principal_amount * annual_rate * repaid_frac, 6),
    interest_outstanding  = ROUND(principal_amount * annual_rate * (1 - repaid_frac), 6);

UPDATE tmp_loan SET total_outstanding = principal_outstanding + interest_outstanding;

INSERT INTO public.m_loan (
    id, account_no, client_id, product_id,
    loan_status_id, loan_type_enum,
    currency_code, currency_digits, currency_multiplesof,
    principal_amount_proposed, principal_amount,
    approved_principal, net_disbursal_amount,
    annual_nominal_interest_rate, nominal_interest_rate_per_period,
    interest_method_enum, interest_calculated_in_period_enum,
    term_frequency, term_period_frequency_enum,
    repay_every, repayment_period_frequency_enum, number_of_repayments,
    amortization_method_enum,
    submittedon_date, approvedon_date,
    expected_disbursedon_date, disbursedon_date,
    expected_firstrepaymenton_date, expected_maturedon_date,
    principal_disbursed_derived, principal_repaid_derived,
    principal_writtenoff_derived, principal_outstanding_derived,
    interest_charged_derived, interest_repaid_derived,
    interest_waived_derived, interest_writtenoff_derived,
    interest_outstanding_derived,
    fee_charges_charged_derived, fee_charges_repaid_derived,
    fee_charges_waived_derived, fee_charges_writtenoff_derived,
    fee_charges_outstanding_derived,
    penalty_charges_charged_derived, penalty_charges_repaid_derived,
    penalty_charges_waived_derived, penalty_charges_writtenoff_derived,
    penalty_charges_outstanding_derived,
    total_expected_repayment_derived, total_repayment_derived,
    total_expected_costofloan_derived, total_costofloan_derived,
    total_waived_derived, total_writtenoff_derived, total_outstanding_derived,
    loan_counter, is_npa,
    loan_transaction_strategy_code, loan_transaction_strategy_name,
    loan_schedule_type, loan_schedule_processing_type,
    created_on_utc, created_by, last_modified_by, last_modified_on_utc
)
SELECT
    l.loan_id,
    'LN' || LPAD(l.loan_id::text, 7, '0'),
    l.client_id, l.product_id,
    300, 1,
    'USD', 2, 0,
    l.principal_amount, l.principal_amount,
    l.principal_amount, l.principal_amount,
    ROUND(l.annual_rate * 100, 4),
    ROUND(l.annual_rate * 100 / 12, 4),
    0, 1,
    l.term_months, 2,
    1, 2, l.term_months,
    1,
    l.disburse_date - 5, l.disburse_date - 3,
    l.disburse_date,     l.disburse_date,
    l.disburse_date + 30, l.mature_date,
    l.principal_amount,
    l.principal_repaid,
    0,
    l.principal_outstanding,
    l.interest_charged,
    l.interest_repaid,
    0, 0,
    l.interest_outstanding,
    0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,
    ROUND(l.principal_amount * (1 + l.annual_rate), 6),
    ROUND(l.principal_repaid + l.interest_repaid, 6),
    ROUND(l.principal_amount * l.annual_rate, 6),
    ROUND(l.interest_repaid, 6),
    0, 0,
    l.total_outstanding,
    1,
    l.overdue_days >= 90,
    'mifos-standard-strategy',
    'Penalties, Fees, Interest, Principal order',
    'CUMULATIVE', 'HORIZONTAL',
    NOW(), 1, 1, NOW()
FROM tmp_loan l;

INSERT INTO public.m_loan_transaction (
    loan_id, office_id, is_reversed, transaction_type_enum, transaction_date, amount,
    principal_portion_derived, interest_portion_derived,
    fee_charges_portion_derived, penalty_charges_portion_derived,
    outstanding_loan_balance_derived,
    submitted_on_date, created_on_utc, created_by, last_modified_by, last_modified_on_utc
)
SELECT
    l.loan_id, l.office_id, FALSE,
    1, l.disburse_date, l.principal_amount,
    l.principal_amount, 0, 0, 0, l.principal_amount,
    l.disburse_date, NOW(), 1, 1, NOW()
FROM tmp_loan l;

INSERT INTO public.m_loan_transaction (
    loan_id, office_id, is_reversed, transaction_type_enum, transaction_date, amount,
    principal_portion_derived, interest_portion_derived,
    fee_charges_portion_derived, penalty_charges_portion_derived,
    outstanding_loan_balance_derived,
    submitted_on_date, created_on_utc, created_by, last_modified_by, last_modified_on_utc
)
SELECT
    l.loan_id, l.office_id, FALSE,
    2,
    l.disburse_date + (m.mn * 30),
    ROUND((l.principal_amount / l.term_months) + (l.principal_amount * l.annual_rate / 12), 6),
    ROUND(l.principal_amount / l.term_months, 6),
    ROUND(l.principal_amount * l.annual_rate / 12, 6),
    0, 0,
    GREATEST(l.principal_amount - ROUND(l.principal_amount / l.term_months, 6) * m.mn, 0),
    l.disburse_date + (m.mn * 30),
    NOW(), 1, 1, NOW()
FROM tmp_loan l
CROSS JOIN generate_series(1,
    CASE
        WHEN l.overdue_days = 0
            THEN LEAST(l.vintage_months, l.term_months)
        ELSE
            GREATEST(l.vintage_months - CEIL(l.overdue_days::numeric / 30)::int, 1)
    END
) AS m(mn)
WHERE l.disburse_date + (m.mn * 30) <= current_date;

INSERT INTO public.m_loan_delinquency_tag_history (
    delinquency_range_id, loan_id, addedon_date, liftedon_date,
    created_by, created_on_utc, version, last_modified_by, last_modified_on_utc
)
SELECT
    101,
    l.loan_id,
    l.disburse_date + 90,
    CASE
        WHEN l.overdue_days >= 30  THEN l.disburse_date + 120
        ELSE NULL
    END,
    1, NOW(), 1, 1, NOW()
FROM tmp_loan l
WHERE l.overdue_days > 0;

INSERT INTO public.m_loan_delinquency_tag_history (
    delinquency_range_id, loan_id, addedon_date, liftedon_date,
    created_by, created_on_utc, version, last_modified_by, last_modified_on_utc
)
SELECT
    102,
    l.loan_id,
    l.disburse_date + 120,
    CASE
        WHEN l.overdue_days >= 60  THEN l.disburse_date + 150
        ELSE NULL
    END,
    1, NOW(), 1, 1, NOW()
FROM tmp_loan l
WHERE l.overdue_days >= 30;

INSERT INTO public.m_loan_delinquency_tag_history (
    delinquency_range_id, loan_id, addedon_date, liftedon_date,
    created_by, created_on_utc, version, last_modified_by, last_modified_on_utc
)
SELECT
    103,
    l.loan_id,
    l.disburse_date + 150,
    CASE
        WHEN l.overdue_days >= 90  THEN l.disburse_date + 180
        ELSE NULL
    END,
    1, NOW(), 1, 1, NOW()
FROM tmp_loan l
WHERE l.overdue_days >= 60;

INSERT INTO public.m_loan_delinquency_tag_history (
    delinquency_range_id, loan_id, addedon_date, liftedon_date,
    created_by, created_on_utc, version, last_modified_by, last_modified_on_utc
)
SELECT
    104,
    l.loan_id,
    l.disburse_date + 180,
    NULL,
    1, NOW(), 1, 1, NOW()
FROM tmp_loan l
WHERE l.overdue_days >= 90;

INSERT INTO public.batch_job_instance (job_instance_id, version, job_name, job_key)
VALUES (9001, 1, 'LOAN_COB', md5('LOAN_COB_SEED'))
ON CONFLICT DO NOTHING;

INSERT INTO public.batch_job_execution
    (job_execution_id, version, job_instance_id, status,
     create_time, start_time, end_time, exit_code, exit_message, last_updated)
VALUES
    (9001, 1, 9001, 'COMPLETED',
     NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '30 minutes',
     NOW() - INTERVAL '5 minutes', 'COMPLETED', '', NOW() - INTERVAL '5 minutes');

DROP TABLE tmp_loan;

COMMIT;

SELECT entity, cnt FROM (
    SELECT 'offices'      AS entity, COUNT(*) AS cnt FROM public.m_office      WHERE id >= 100 UNION ALL
    SELECT 'clients',                COUNT(*)         FROM public.m_client      WHERE id >= 100 UNION ALL
    SELECT 'loan_products',          COUNT(*)         FROM public.m_product_loan WHERE id >= 100 UNION ALL
    SELECT 'loans',                  COUNT(*)         FROM public.m_loan        WHERE id >= 100 UNION ALL
    SELECT 'transactions',           COUNT(*)         FROM public.m_loan_transaction WHERE loan_id >= 100 UNION ALL
    SELECT 'delinq_tags',            COUNT(*)         FROM public.m_loan_delinquency_tag_history WHERE loan_id >= 100 UNION ALL
    SELECT 'delinq_ranges',          COUNT(*)         FROM public.m_delinquency_range WHERE id >= 100
) s ORDER BY entity;
