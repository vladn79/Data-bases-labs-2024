CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


CREATE TABLE Countries (
    country_id SERIAL PRIMARY KEY,
    code VARCHAR(2) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE CardBrands (
    brand_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE CardTypes (
    type_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE BankIssuers (
    issuer_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL
);

CREATE TABLE TokenTypes (
    token_type_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE OrderTypes (
    order_type_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE PaymentSources (
    source_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE TransactionStatus (
    status_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE ErrorCodes (
    error_code_id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    message TEXT NOT NULL,
    description TEXT
);

CREATE TABLE Channels (
    channel_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
);


CREATE TABLE Users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP,
    updated_by_user_id INTEGER REFERENCES Users(user_id),
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE Cards (
    card_id SERIAL PRIMARY KEY,
    brand_id INTEGER REFERENCES CardBrands(brand_id),
    type_id INTEGER REFERENCES CardTypes(type_id),
    bank_issuer_id INTEGER REFERENCES BankIssuers(issuer_id),
    country_id INTEGER REFERENCES Countries(country_id),
    masked_number VARCHAR(19) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE SavedPaymentMethods (
    payment_method_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES Users(user_id),
    card_id INTEGER REFERENCES Cards(card_id),
    token_type_id INTEGER REFERENCES TokenTypes(token_type_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE Invoices (
    invoice_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES Users(user_id),
    number INTEGER NOT NULL,
    amount_usd DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP
);

CREATE TABLE Transactions (
    transaction_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES Users(user_id),
    channel_id INTEGER REFERENCES Channels(channel_id),
    order_type_id INTEGER REFERENCES OrderTypes(order_type_id),
    payment_source_id INTEGER REFERENCES PaymentSources(source_id),
    card_id INTEGER REFERENCES Cards(card_id),
    amount_usd DECIMAL(10,2) NOT NULL,
    is_secured BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status_id INTEGER REFERENCES TransactionStatus(status_id),
    error_code_id INTEGER REFERENCES ErrorCodes(error_code_id),
    ip_country VARCHAR(2),
    invoice_id INTEGER REFERENCES Invoices(invoice_id)
);

CREATE TABLE RetryAttempts (
    retry_id SERIAL PRIMARY KEY,
    transaction_id INTEGER REFERENCES Transactions(transaction_id),
    attempt_number INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status_id INTEGER REFERENCES TransactionStatus(status_id)
);

CREATE TABLE AuditLogs (
    log_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES Users(user_id),
    action VARCHAR(50) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON Users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_channels_updated_at
    BEFORE UPDATE ON Channels
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


CREATE OR REPLACE FUNCTION soft_delete_record()
RETURNS TRIGGER AS $$
BEGIN
    NEW.deleted_at = CURRENT_TIMESTAMP;
    NEW.is_active = false;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO AuditLogs (user_id, action, old_values, new_values)
    VALUES (
        COALESCE(NEW.updated_by_user_id, OLD.updated_by_user_id),
        TG_OP,
        row_to_json(OLD),
        row_to_json(NEW)
    );
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE VIEW successful_transactions AS
SELECT 
    t.transaction_id,
    u.email,
    c.name as channel_name,
    t.amount_usd,
    t.created_at
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
JOIN Channels c ON t.channel_id = c.channel_id
WHERE t.status_id = (SELECT status_id FROM TransactionStatus WHERE name = 'SUCCESS');

CREATE VIEW failed_transactions_summary AS
SELECT 
    e.code,
    e.message,
    COUNT(*) as error_count,
    AVG(t.amount_usd) as avg_amount,
    date_trunc('day', t.created_at) as error_date
FROM Transactions t
JOIN ErrorCodes e ON t.error_code_id = e.error_code_id
GROUP BY e.code, e.message, date_trunc('day', t.created_at);


CREATE OR REPLACE PROCEDURE process_transaction(
    p_user_id INT,
    p_amount DECIMAL,
    p_channel_id INT,
    p_payment_source_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO Transactions (
        user_id, 
        amount_usd, 
        channel_id, 
        payment_source_id,
        status_id
    )
    VALUES (
        p_user_id,
        p_amount,
        p_channel_id,
        p_payment_source_id,
        (SELECT status_id FROM TransactionStatus WHERE name = 'PENDING')
    );
END;
$$;


CREATE OR REPLACE FUNCTION get_user_transaction_stats(p_user_id INT)
RETURNS TABLE (
    total_transactions BIGINT,
    total_amount DECIMAL,
    avg_amount DECIMAL,
    success_rate DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_transactions,
        SUM(amount_usd) as total_amount,
        AVG(amount_usd) as avg_amount,
        (COUNT(*) FILTER (WHERE status_id = 
            (SELECT status_id FROM TransactionStatus WHERE name = 'SUCCESS'))::DECIMAL / 
            COUNT(*)::DECIMAL * 100) as success_rate
    FROM Transactions
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;