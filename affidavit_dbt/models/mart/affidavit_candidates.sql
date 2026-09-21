SELECT
    a.ACCOUNT_ID,
    a.CUSTOMER_ID,
    c.CUSTOMER_NAME,
    c.STATE         AS CUSTOMER_STATE,
    a.ORIGINAL_CREDITOR,
    a.BALANCE,
    a.ACCOUNT_STATUS,
    lc.CASE_ID,
    lc.CASE_TYPE,
    lc.CASE_STATUS,
    lc.COURT_STATE,
    lc.FILING_DATE  AS CASE_FILING_DATE
FROM {{ ref('stg_accounts') }} a
JOIN {{ ref('stg_legal_cases') }} lc ON a.ACCOUNT_ID = lc.ACCOUNT_ID
JOIN {{ ref('stg_customers') }} c    ON a.CUSTOMER_ID = c.CUSTOMER_ID
WHERE a.ACCOUNT_STATUS = 'ACTIVE'
  AND a.BALANCE > 1000
  AND lc.CASE_STATUS = 'OPEN'
