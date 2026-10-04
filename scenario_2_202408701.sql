-- =====================================================
-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 2: Computer Laboratory Reservations
-- Student number: STUDENTNUMBER
-- Run in pgAdmin Query Tool. Check the "Messages" tab for RAISE NOTICE output.
-- =====================================================

DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

-- STEP 1: Tables and at least three sessions
CREATE TABLE lab_sessions (
    session_id             SERIAL PRIMARY KEY,
    session_name           VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id   SERIAL PRIMARY KEY,
    session_id       INT NOT NULL REFERENCES lab_sessions(session_id),
    lecturer         VARCHAR(100) NOT NULL,
    workstations     INT NOT NULL CHECK (workstations > 0),
    status           VARCHAR(20) NOT NULL DEFAULT 'RESERVED'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
    ('Monday 08:00 - Programming Lab', 30),
    ('Tuesday 10:00 - Networking Lab', 4),
    ('Wednesday 14:00 - Database Lab', 0);

-- STEP 2: IF / ELSIF / ELSE - full, nearly full, enough workstations
DO $$
DECLARE
    s RECORD;
BEGIN
    FOR s IN SELECT session_name, available_workstations FROM lab_sessions ORDER BY session_id LOOP
        IF s.available_workstations = 0 THEN
            RAISE NOTICE '% : FULL', s.session_name;
        ELSIF s.available_workstations <= 5 THEN
            RAISE NOTICE '% : NEARLY FULL (% left)', s.session_name, s.available_workstations;
        ELSE
            RAISE NOTICE '% : ENOUGH WORKSTATIONS (% left)', s.session_name, s.available_workstations;
        END IF;
    END LOOP;
END $$;

-- STEP 3: WHILE (preparation reminders) and numeric FOR (workstation checks)
DO $$
DECLARE
    n INT := 1;
BEGIN
    WHILE n <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', n;
        n := n + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Workstation check %', i;
    END LOOP;
END $$;

-- STEP 4: reserve_workstations procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(p_session_id INT, p_lecturer VARCHAR, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_avail INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid number of workstations: %. Must be greater than zero.', p_qty;
    END IF;

    SELECT available_workstations INTO v_avail
    FROM lab_sessions WHERE session_id = p_session_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session % does not exist.', p_session_id;
    END IF;

    IF v_avail >= p_qty THEN
        UPDATE lab_sessions SET available_workstations = available_workstations - p_qty
        WHERE session_id = p_session_id;
        INSERT INTO reservations (session_id, lecturer, workstations)
        VALUES (p_session_id, p_lecturer, p_qty);
        RAISE NOTICE 'Reservation recorded: % reserved % workstations.', p_lecturer, p_qty;
    ELSE
        RAISE NOTICE 'REJECTED: % requested % but only % available.', p_lecturer, p_qty, v_avail;
    END IF;
END $$;

-- STEP 5: two valid reservations + one exceeding capacity
CALL reserve_workstations(1, 'Mr. Banda', 20);   -- valid
CALL reserve_workstations(2, 'Mrs. Phiri', 3);   -- valid
CALL reserve_workstations(2, 'Dr. Mwansa', 10);  -- exceeds capacity

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

-- STEP 6: cancel_reservation procedure (second call must not release again)
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_session INT;
    v_qty     INT;
    v_status  VARCHAR;
BEGIN
    SELECT session_id, workstations, status INTO v_session, v_qty, v_status
    FROM reservations WHERE reservation_id = p_reservation_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Reservation % does not exist.', p_reservation_id;
    ELSIF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % already cancelled. Nothing released.', p_reservation_id;
    ELSE
        UPDATE reservations SET status = 'CANCELLED' WHERE reservation_id = p_reservation_id;
        UPDATE lab_sessions SET available_workstations = available_workstations + v_qty
        WHERE session_id = v_session;
        RAISE NOTICE 'Reservation % cancelled. % workstations released.', p_reservation_id, v_qty;
    END IF;
END $$;

CALL cancel_reservation(1);  -- releases workstations
CALL cancel_reservation(1);  -- second call: nothing released

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

-- STEP 7: explicit cursor - sessions with few workstations remaining
DO $$
DECLARE
    cur_few CURSOR FOR
        SELECT session_name, available_workstations FROM lab_sessions
        WHERE available_workstations <= 5 ORDER BY available_workstations;
    rec RECORD;
BEGIN
    OPEN cur_few;
    LOOP
        FETCH cur_few INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few workstations left: % (% left)', rec.session_name, rec.available_workstations;
    END LOOP;
    CLOSE cur_few;
END $$;

-- STEP 8: request zero workstations, handled with EXCEPTION block
DO $$
BEGIN
    CALL reserve_workstations(1, 'Mr. Tembo', 0);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- STEP 9: final results
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;
