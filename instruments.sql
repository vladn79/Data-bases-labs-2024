CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER update_users_modified
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_channels_modified
    BEFORE UPDATE ON channels
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


CREATE OR REPLACE FUNCTION soft_delete_record()
RETURNS TRIGGER AS $$
BEGIN
    NEW.deleted_at = CURRENT_TIMESTAMP;
    NEW.is_active = false;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER soft_delete_users
    BEFORE UPDATE OF is_active ON users
    FOR EACH ROW
    WHEN (NEW.is_active = false)
    EXECUTE FUNCTION soft_delete_record();

CREATE TRIGGER soft_delete_channels
    BEFORE UPDATE OF is_active ON channels
    FOR EACH ROW
    WHEN (NEW.is_active = false)
    EXECUTE FUNCTION soft_delete_record();

CREATE TRIGGER soft_delete_paymentmethods
    BEFORE UPDATE OF is_active ON savedpaymentmethods
    FOR EACH ROW
    WHEN (NEW.is_active = false)
    EXECUTE FUNCTION soft_delete_record();


CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO auditlogs (
        userid,
        action,
        old_values,
        new_values
    )
    VALUES (
        COALESCE(NEW.updatedbyuserid, OLD.updatedbyuserid),
        TG_OP,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER audit_users_changes
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER audit_transactions_changes
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION log_changes();


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


CREATE OR REPLACE PROCEDURE process_transaction(
    p_userid INTEGER,
    p_amount DECIMAL,
    p_channelid INTEGER,
    p_paymentsourceid INTEGER,
    p_cardid INTEGER,
    p_is_secured BOOLEAN DEFAULT false
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoiceid INTEGER;
    v_statusid INTEGER;
BEGIN

    INSERT INTO invoices (userid, number, amountusd)
    SELECT 
        p_userid,
        COALESCE(MAX(number), 0) + 1,
        p_amount
    FROM invoices
    WHERE userid = p_userid
    RETURNING invoiceid INTO v_invoiceid;


    SELECT statusid INTO v_statusid
    FROM transactionstatus
    WHERE name = 'PENDING';


    INSERT INTO transactions (
        userid,
        channelid,
        paymentsourceid,
        cardid,
        amountusd,
        is_secured,
        statusid,
        invoiceid
    ) VALUES (
        p_userid,
        p_channelid,
        p_paymentsourceid,
        p_cardid,
        p_amount,
        p_is_secured,
        v_statusid,
        v_invoiceid
    );
    
    COMMIT;
END;
$$;


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


CREATE OR REPLACE FUNCTION validate_transaction()
RETURNS TRIGGER AS $$
BEGIN

    IF NOT EXISTS (SELECT 1 FROM users WHERE userid = NEW.userid AND is_active = true) THEN
        RAISE EXCEPTION 'Invalid or inactive user';
    END IF;
    

    IF NOT EXISTS (SELECT 1 FROM channels WHERE channelid = NEW.channelid AND is_active = true) THEN
        RAISE EXCEPTION 'Invalid or inactive channel';
    END IF;
    

    IF NEW.amountusd <= 0 THEN
        RAISE EXCEPTION 'Transaction amount must be positive';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_transaction_before_insert
    BEFORE INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION validate_transaction();