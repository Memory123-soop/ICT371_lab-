-- =====================================================
-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 1: University Library Book Loans
-- Student number: STUDENTNUMBER
-- Run in pgAdmin Query Tool. Check the "Messages" tab for RAISE NOTICE output.
-- =====================================================

-- Clean start so the script can be re-run
DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;

-- STEP 1: Create tables and add at least three books
CREATE TABLE books (
    book_id          SERIAL PRIMARY KEY,
    title            VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id        SERIAL PRIMARY KEY,
    book_id        INT NOT NULL REFERENCES books(book_id),
    student_number VARCHAR(20) NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    loan_status    VARCHAR(20) NOT NULL DEFAULT 'BORROWED'
);

INSERT INTO books (title, available_copies) VALUES
    ('Database System Concepts', 5),
    ('Operating Systems', 1),
    ('Computer Networks', 0);

-- STEP 2: IF / ELSIF / ELSE - unavailable, low, or sufficiently stocked
DO $$
DECLARE
    b RECORD;
BEGIN
    FOR b IN SELECT title, available_copies FROM books ORDER BY book_id LOOP
        IF b.available_copies = 0 THEN
            RAISE NOTICE '% : UNAVAILABLE (% copies)', b.title, b.available_copies;
        ELSIF b.available_copies <= 2 THEN
            RAISE NOTICE '% : LOW ON COPIES (% copies)', b.title, b.available_copies;
        ELSE
            RAISE NOTICE '% : SUFFICIENTLY STOCKED (% copies)', b.title, b.available_copies;
        END IF;
    END LOOP;
END $$;

-- STEP 3: WHILE loop (overdue reminders) and numeric FOR loop (shelf numbers)
DO $$
DECLARE
    n INT := 1;
BEGIN
    WHILE n <= 3 LOOP
        RAISE NOTICE 'Overdue reminder number %', n;
        n := n + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number %', i;
    END LOOP;
END $$;

-- STEP 4: borrow_book procedure (check copies, reduce stock, record loan)
CREATE OR REPLACE PROCEDURE borrow_book(p_book_id INT, p_student VARCHAR, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_avail INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. Quantity must be greater than zero.', p_qty;
    END IF;

    SELECT available_copies INTO v_avail
    FROM books WHERE book_id = p_book_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book % does not exist.', p_book_id;
    END IF;

    IF v_avail >= p_qty THEN
        UPDATE books SET available_copies = available_copies - p_qty
        WHERE book_id = p_book_id;
        INSERT INTO book_loans (book_id, student_number, quantity)
        VALUES (p_book_id, p_student, p_qty);
        RAISE NOTICE 'Loan recorded: student %, book %, qty %', p_student, p_book_id, p_qty;
    ELSE
        RAISE NOTICE 'REJECTED: student % requested % but only % available.', p_student, p_qty, v_avail;
    END IF;
END $$;

-- STEP 5: two valid loans + one request exceeding available copies
CALL borrow_book(1, '2023001', 2);   -- valid
CALL borrow_book(2, '2023002', 1);   -- valid
CALL borrow_book(1, '2023003', 10);  -- exceeds copies, not recorded

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

-- STEP 6: return_book procedure (second call must not restore copies again)
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_book   INT;
    v_qty    INT;
    v_status VARCHAR;
BEGIN
    SELECT book_id, quantity, loan_status INTO v_book, v_qty, v_status
    FROM book_loans WHERE loan_id = p_loan_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Loan % does not exist.', p_loan_id;
    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % already returned. No copies restored.', p_loan_id;
    ELSE
        UPDATE book_loans SET loan_status = 'RETURNED' WHERE loan_id = p_loan_id;
        UPDATE books SET available_copies = available_copies + v_qty WHERE book_id = v_book;
        RAISE NOTICE 'Loan % returned. % copies restored.', p_loan_id, v_qty;
    END IF;
END $$;

CALL return_book(1);  -- restores copies
CALL return_book(1);  -- second call: nothing restored

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

-- STEP 7: explicit cursor - books with few copies remaining
DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT title, available_copies FROM books
        WHERE available_copies <= 2 ORDER BY available_copies, title;
    rec RECORD;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few copies left: % (% copies)', rec.title, rec.available_copies;
    END LOOP;
    CLOSE cur_low;
END $$;

-- STEP 8: borrow zero copies, handled with an EXCEPTION block
DO $$
BEGIN
    CALL borrow_book(1, '2023004', 0);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- STEP 9: final results
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;
