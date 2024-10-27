CREATE OR REPLACE VIEW successful_transactions AS
SELECT 
    t.transaction_id,
    u.email,
    c.name as channel_name,
    t.amount_usd,
    t.created_at,
    ts.name as statusname
FROM transactions t
JOIN users u ON t.user_id = u.user_id
JOIN channels c ON t.channel_id = c.channel_id
JOIN transactionstatus ts ON t.status_id = ts.status_id
WHERE ts.name = 'SUCCESS'
AND u.is_active = true;

CREATE OR REPLACE VIEW failed_transactions_summary AS
SELECT 
    ec.code as code,
    ec.message as message,
    COUNT(*) as error_count,
    AVG(t.amount_usd) as avg_amount,
    date_trunc('day', t.created_at) as error_date
FROM transactions t
JOIN errorcodes ec ON t.error_code_id = ec.error_code_id
WHERE t.status_id = (
    SELECT status_id 
    FROM transactionstatus 
    WHERE name = 'FAILED'
)
GROUP BY 
    ec.code,
    ec.message,
    date_trunc('day', t.created_at);