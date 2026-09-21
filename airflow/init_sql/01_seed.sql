-- Customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id   INTEGER PRIMARY KEY,
    customer_name VARCHAR(100),
    state         CHAR(2),
    email         VARCHAR(100),
    created_date  DATE
);

TRUNCATE customers;
INSERT INTO customers VALUES
(2001, 'Alice Morgan',   'TX', 'alice.morgan@email.com',   '2022-01-10'),
(2002, 'Bob Nguyen',     'FL', 'bob.nguyen@email.com',     '2022-03-15'),
(2003, 'Carol Simmons',  'NY', 'carol.simmons@email.com',  '2022-06-20'),
(2004, 'David Okafor',   'CA', 'david.okafor@email.com',   '2023-01-05'),
(2005, 'Eva Ruiz',       'IL', 'eva.ruiz@email.com',       '2023-04-18');

-- Accounts
CREATE TABLE IF NOT EXISTS accounts (
    account_id          INTEGER PRIMARY KEY,
    customer_id         INTEGER,
    original_creditor   VARCHAR(100),
    balance             NUMERIC(10,2),
    account_status      VARCHAR(20),
    account_open_date   DATE
);

TRUNCATE accounts;
INSERT INTO accounts VALUES
(6001, 2001, 'First National Bank',  3500.00, 'ACTIVE',   '2022-01-15'),
(6002, 2002, 'Capital Finance',       800.00, 'ACTIVE',   '2022-03-20'),
(6003, 2003, 'Midwest Credit',       4200.00, 'ACTIVE',   '2022-06-25'),
(6004, 2004, 'Pacific Lending',       200.00, 'INACTIVE', '2023-01-10'),
(6005, 2005, 'Southern Trust',       1750.00, 'ACTIVE',   '2023-04-20');

-- Legal Cases
CREATE TABLE IF NOT EXISTS legal_cases (
    case_id      INTEGER PRIMARY KEY,
    account_id   INTEGER,
    case_type    VARCHAR(50),
    case_status  VARCHAR(20),
    court_state  CHAR(2),
    filing_date  DATE
);

TRUNCATE legal_cases;
INSERT INTO legal_cases VALUES
(8001, 6001, 'DEBT_COLLECTION', 'OPEN',   'TX', '2025-03-01'),
(8002, 6002, 'DEBT_COLLECTION', 'CLOSED', 'FL', '2025-01-15'),
(8003, 6003, 'DEBT_COLLECTION', 'OPEN',   'NY', '2025-04-10'),
(8004, 6005, 'DEBT_COLLECTION', 'OPEN',   'IL', '2025-05-20');

-- Payments
CREATE TABLE IF NOT EXISTS payments (
    payment_id      INTEGER PRIMARY KEY,
    account_id      INTEGER,
    payment_date    DATE,
    payment_amount  NUMERIC(10,2),
    payment_status  VARCHAR(20)
);

TRUNCATE payments;
INSERT INTO payments VALUES
(9001, 6001, '2025-01-10', 200.00, 'SUCCESS'),
(9002, 6001, '2025-02-10', 150.00, 'SUCCESS'),
(9003, 6003, '2025-03-05', 300.00, 'SUCCESS'),
(9004, 6005, '2025-04-01', 100.00, 'FAILED'),
(9005, 6005, '2025-04-15', 100.00, 'SUCCESS');
