-- =====================================================
-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 4: Campus Clinic Medicine Dispensing
-- Student number: STUDENTNUMBER
-- Run in pgAdmin Query Tool. Check the "Messages" tab for RAISE NOTICE output.
-- =====================================================

DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

-- STEP 1: Tables and at least three medicines
CREATE TABLE medicines (
    medicine_id    SERIAL PRIMARY KEY,
    medicine_name  VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id      SERIAL PRIMARY KEY,
    medicine_id    INT NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    status         VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
    ('Paracetamol 500mg', 100),
    ('Amoxicillin 250mg', 8),
    ('Oral Rehydration Salts', 0);

-- STEP 2: IF / ELSIF / ELSE - out of stock, low, sufficiently stocked
DO $$
DECLARE
    m RECORD;
BEGIN
    FOR m IN SELECT medicine_name, stock_quantity FROM medicines ORDER BY medicine_id LOOP
        IF m.stock_quantity = 0 THEN
            RAISE NOTICE '% : OUT OF STOCK', m.medicine_name;
        ELSIF m.stock_quantity <= 10 THEN
            RAISE NOTICE '% : LOW ON STOCK (%)', m.medicine_name, m.stock_quantity;
        ELSE
            RAISE NOTICE '% : SUFFICIENTLY STOCKED (%)', m.medicine_name, m.stock_quantity;
        END IF;
    END LOOP;
END $$;

-- STEP 3: WHILE (stock review days) and numeric FOR (shelf inspections)
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Stock review day %', d;
        d := d + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection %', i;
    END LOOP;
END $$;

-- STEP 4: dispense_medicine procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(p_medicine_id INT, p_student VARCHAR, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. Quantity must be greater than zero.', p_qty;
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines WHERE medicine_id = p_medicine_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine % does not exist.', p_medicine_id;
    END IF;

    IF v_stock >= p_qty THEN
        UPDATE medicines SET stock_quantity = stock_quantity - p_qty
        WHERE medicine_id = p_medicine_id;
        INSERT INTO dispensing_records (medicine_id, student_number, quantity)
        VALUES (p_medicine_id, p_student, p_qty);
        RAISE NOTICE 'Dispensed % of medicine % to student %.', p_qty, p_medicine_id, p_student;
    ELSE
        RAISE NOTICE 'REJECTED: requested % but only % in stock.', p_qty, v_stock;
    END IF;
END $$;

-- STEP 5: two valid quantities + one exceeding stock
CALL dispense_medicine(1, '2023001', 20);  -- valid
CALL dispense_medicine(2, '2023002', 3);   -- valid
CALL dispense_medicine(2, '2023003', 50);  -- exceeds stock

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- STEP 6: reverse_dispensing procedure (stock restored only once)
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_med    INT;
    v_qty    INT;
    v_status VARCHAR;
BEGIN
    SELECT medicine_id, quantity, status INTO v_med, v_qty, v_status
    FROM dispensing_records WHERE record_id = p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Record % does not exist.', p_record_id;
    ELSIF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % already reversed. Stock not restored again.', p_record_id;
    ELSE
        UPDATE dispensing_records SET status = 'REVERSED' WHERE record_id = p_record_id;
        UPDATE medicines SET stock_quantity = stock_quantity + v_qty WHERE medicine_id = v_med;
        RAISE NOTICE 'Record % reversed. % units restored.', p_record_id, v_qty;
    END IF;
END $$;

CALL reverse_dispensing(1);  -- restores stock
CALL reverse_dispensing(1);  -- second call: nothing restored

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- STEP 7: explicit cursor (with parameter) - medicines below a low-stock threshold
DO $$
DECLARE
    cur_low CURSOR (p_threshold INT) FOR
        SELECT medicine_name, stock_quantity FROM medicines
        WHERE stock_quantity < p_threshold ORDER BY stock_quantity;
    rec RECORD;
BEGIN
    OPEN cur_low(11);
    LOOP
        FETCH cur_low INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Below threshold: % (% units)', rec.medicine_name, rec.stock_quantity;
    END LOOP;
    CLOSE cur_low;
END $$;

-- STEP 8: negative quantity, handled with EXCEPTION block
DO $$
BEGIN
    CALL dispense_medicine(1, '2023004', -5);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- STEP 9: final results
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;
