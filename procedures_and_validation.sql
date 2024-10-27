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
    -- Create invoice
    INSERT INTO invoices (userid, number, amountusd)
    SELECT 
        p_userid,
        COALESCE(MAX(number), 0) + 1,
        p_amount
    FROM invoices
    WHERE userid = p_userid
    RETURNING invoiceid INTO v_invoiceid;

    -- Get pending status
    SELECT statusid INTO v_statusid
    FROM transactionstatus
    WHERE name = 'PENDING';

    -- Create transaction
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

-- Валідаційна функція для транзакцій
CREATE OR REPLACE FUNCTION validate_transaction()
RETURNS TRIGGER AS $$
BEGIN
    -- Перевірка користувача
    IF NOT EXISTS (SELECT 1 FROM users WHERE userid = NEW.userid AND is_active = true) THEN
        RAISE EXCEPTION 'Invalid or inactive user';
    END IF;
    
    -- Перевірка каналу
    IF NOT EXISTS (SELECT 1 FROM channels WHERE channelid = NEW.channelid AND is_active = true) THEN
        RAISE EXCEPTION 'Invalid or inactive channel';
    END IF;
    
    -- Перевірка суми
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