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