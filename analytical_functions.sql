-- Функція для отримання статистики користувача
CREATE OR REPLACE FUNCTION get_user_transaction_stats(
    p_userid INTEGER,
    p_start_date TIMESTAMP DEFAULT NULL,
    p_end_date TIMESTAMP DEFAULT NULL
)
RETURNS TABLE (
    total_transactions BIGINT,
    total_amount DECIMAL(10,2),
    avg_amount DECIMAL(10,2),
    success_rate DECIMAL(5,2),
    most_used_payment_source VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH transaction_data AS (
        SELECT 
            COUNT(*) as total_txns,
            SUM(amountusd) as total_amt,
            AVG(amountusd) as avg_amt,
            (COUNT(*) FILTER (WHERE ts.name = 'SUCCESS')::DECIMAL / 
             COUNT(*)::DECIMAL * 100) as success_rt,
            mode() WITHIN GROUP (ORDER BY ps.name) as most_used_source
        FROM transactions t
        JOIN transactionstatus ts ON t.statusid = ts.statusid
        JOIN paymentsources ps ON t.paymentsourceid = ps.sourceid
        WHERE t.userid = p_userid
        AND (p_start_date IS NULL OR t.createdat >= p_start_date)
        AND (p_end_date IS NULL OR t.createdat <= p_end_date)
    )
    SELECT 
        total_txns,
        total_amt,
        avg_amt,
        success_rt,
        most_used_source
    FROM transaction_data;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_transaction_history(
    p_userid INTEGER,
    p_limit INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    transactionid INTEGER,
    createdat TIMESTAMP,
    amountusd DECIMAL(10,2),
    status VARCHAR,
    channelname VARCHAR,
    paymentsource VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.transactionid,
        t.createdat,
        t.amountusd,
        ts.name as status,
        c.name as channelname,
        ps.name as paymentsource
    FROM transactions t
    JOIN transactionstatus ts ON t.statusid = ts.statusid
    JOIN channels c ON t.channelid = c.channelid
    JOIN paymentsources ps ON t.paymentsourceid = ps.sourceid
    WHERE t.userid = p_userid
    ORDER BY t.createdat DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION analyze_channel_performance(
    p_start_date TIMESTAMP DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date TIMESTAMP DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    channelname VARCHAR,
    total_transactions BIGINT,
    successful_transactions BIGINT,
    success_rate DECIMAL(5,2),
    total_amount DECIMAL(10,2),
    avg_amount DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.name as channelname,
        COUNT(*) as total_transactions,
        COUNT(*) FILTER (WHERE ts.name = 'SUCCESS') as successful_transactions,
        (COUNT(*) FILTER (WHERE ts.name = 'SUCCESS')::DECIMAL / 
         COUNT(*)::DECIMAL * 100) as success_rate,
        SUM(t.amountusd) as total_amount,
        AVG(t.amountusd) as avg_amount
    FROM transactions t
    JOIN channels c ON t.channelid = c.channelid
    JOIN transactionstatus ts ON t.statusid = ts.statusid
    WHERE t.createdat BETWEEN p_start_date AND p_end_date
    GROUP BY c.name
    ORDER BY total_amount DESC;
END;
$$ LANGUAGE plpgsql;