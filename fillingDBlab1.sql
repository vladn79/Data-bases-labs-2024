-- Populate Countries
INSERT INTO Countries (code, name) VALUES 
('US', 'United States'),
('GB', 'United Kingdom'),
('DE', 'Germany'),
('FR', 'France'),
('UA', 'Ukraine');

-- Populate CardBrands
INSERT INTO CardBrands (name, description) VALUES 
('Visa', 'Visa International'),
('Mastercard', 'Mastercard Worldwide'),
('American Express', 'American Express Company'),
('Discover', 'Discover Financial Services');

-- Populate CardTypes
INSERT INTO CardTypes (name, description) VALUES 
('Credit', 'Standard credit card'),
('Debit', 'Standard debit card'),
('Prepaid', 'Prepaid card'),
('Corporate', 'Corporate credit card');

-- Populate BankIssuers
INSERT INTO BankIssuers (name, country) VALUES 
('Chase Bank', 'United States'),
('Bank of America', 'United States'),
('Barclays', 'United Kingdom'),
('Deutsche Bank', 'Germany'),
('PrivatBank', 'Ukraine');

-- Populate TokenTypes
INSERT INTO TokenTypes (name, description) VALUES 
('Single-use', 'One-time use token'),
('Multi-use', 'Reusable token'),
('Recurring', 'Token for recurring payments'),
('Secure', 'Enhanced security token');

-- Populate OrderTypes
INSERT INTO OrderTypes (name, description) VALUES 
('Purchase', 'Standard purchase transaction'),
('Subscription', 'Recurring subscription payment'),
('Refund', 'Refund transaction'),
('Chargeback', 'Chargeback transaction');

-- Populate PaymentSources
INSERT INTO PaymentSources (name, description) VALUES 
('Web', 'Website payment'),
('Mobile App', 'Mobile application payment'),
('POS', 'Point of sale terminal'),
('Phone', 'Phone order payment');

-- Populate TransactionStatus
INSERT INTO TransactionStatus (name, description) VALUES 
('PENDING', 'Transaction is being processed'),
('SUCCESS', 'Transaction completed successfully'),
('FAILED', 'Transaction failed'),
('CANCELLED', 'Transaction was cancelled'),
('REFUNDED', 'Transaction was refunded');

-- Populate ErrorCodes
INSERT INTO ErrorCodes (code, message, description) VALUES 
('E001', 'Insufficient funds', 'Card has insufficient funds for the transaction'),
('E002', 'Card expired', 'Card expiration date has passed'),
('E003', 'Invalid card', 'Card number is invalid'),
('E004', 'Declined by issuer', 'Transaction declined by issuing bank');

-- Populate Channels
INSERT INTO Channels (name, description) VALUES 
('Online Store', 'Main e-commerce website'),
('Mobile App', 'Company mobile application'),
('Partner API', 'Partner integration channel'),
('POS System', 'Physical point of sale locations');

-- Populate Users
INSERT INTO Users (email, name) VALUES 
('john.doe@example.com', 'John Doe'),
('jane.smith@example.com', 'Jane Smith'),
('bob.wilson@example.com', 'Bob Wilson'),
('alice.brown@example.com', 'Alice Brown'),
('mike.jones@example.com', 'Mike Jones');

-- Populate Cards
INSERT INTO Cards (brand_id, type_id, bank_issuer_id, country_id, masked_number) VALUES 
(1, 1, 1, 1, '4***********1234'),
(2, 2, 2, 1, '5***********5678'),
(3, 1, 3, 2, '3***********9012'),
(1, 3, 4, 3, '4***********3456'),
(2, 1, 5, 5, '5***********7890');

-- Populate SavedPaymentMethods
INSERT INTO SavedPaymentMethods (user_id, card_id, token_type_id) VALUES 
(1, 1, 2),
(2, 2, 2),
(3, 3, 1),
(4, 4, 3),
(5, 5, 2);

-- Populate Invoices
INSERT INTO Invoices (user_id, number, amount_usd) VALUES 
(1, 1001, 99.99),
(2, 1002, 149.99),
(3, 1003, 199.99),
(4, 1004, 299.99),
(5, 1005, 399.99);

-- Populate Transactions
INSERT INTO Transactions (user_id, channel_id, order_type_id, payment_source_id, card_id, amount_usd, status_id, invoice_id) VALUES 
(1, 1, 1, 1, 1, 99.99, 2, 1),
(2, 2, 1, 2, 2, 149.99, 2, 2),
(3, 3, 1, 1, 3, 199.99, 3, 3),
(4, 4, 1, 3, 4, 299.99, 2, 4),
(5, 1, 1, 1, 5, 399.99, 2, 5);

-- Populate RetryAttempts
INSERT INTO RetryAttempts (transaction_id, attempt_number, status_id) VALUES 
(3, 1, 3),
(3, 2, 3),
(3, 3, 3);

-- Populate AuditLogs
INSERT INTO AuditLogs (user_id, action, old_values, new_values) VALUES 
(1, 'CREATE_TRANSACTION', '{"status": "PENDING"}', '{"status": "SUCCESS"}'),
(2, 'CREATE_TRANSACTION', '{"status": "PENDING"}', '{"status": "SUCCESS"}'),
(3, 'CREATE_TRANSACTION', '{"status": "PENDING"}', '{"status": "FAILED"}'),
(4, 'CREATE_TRANSACTION', '{"status": "PENDING"}', '{"status": "SUCCESS"}'),
(5, 'CREATE_TRANSACTION', '{"status": "PENDING"}', '{"status": "SUCCESS"}');