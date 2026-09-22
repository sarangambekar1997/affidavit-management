{{
    config(
        materialized='incremental',
        unique_key='PAYMENT_ID',
        incremental_strategy='merge'
    )
}}

SELECT
    PAYMENT_ID,
    ACCOUNT_ID,
    PAYMENT_DATE,
    PAYMENT_AMOUNT,
    PAYMENT_STATUS,
    LOADED_AT
FROM {{ ref('stg_payments') }}

{% if is_incremental() %}
WHERE LOADED_AT > (SELECT MAX(LOADED_AT) FROM {{ this }})
{% endif %}
