-- Функція для оновлення updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Тригери для оновлення updated_at
CREATE TRIGGER update_users_modified
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_channels_modified
    BEFORE UPDATE ON channels
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Функція для soft delete
CREATE OR REPLACE FUNCTION soft_delete_record()
RETURNS TRIGGER AS $$
BEGIN
    NEW.deleted_at = CURRENT_TIMESTAMP;
    NEW.is_active = false;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Тригери для soft delete
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