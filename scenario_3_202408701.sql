-- =====================================================
-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 3: Student Hostel Room Allocation
-- Student number: STUDENTNUMBER
-- Run in pgAdmin Query Tool. Check the "Messages" tab for RAISE NOTICE output.
-- =====================================================

DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;

-- STEP 1: Tables and at least three rooms
CREATE TABLE hostel_rooms (
    room_id          SERIAL PRIMARY KEY,
    room_name        VARCHAR(50) NOT NULL,
    available_spaces INT NOT NULL CHECK (available_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id  SERIAL PRIMARY KEY,
    student_number VARCHAR(20) NOT NULL,
    room_id        INT NOT NULL REFERENCES hostel_rooms(room_id),
    status         VARCHAR(20) NOT NULL DEFAULT 'ALLOCATED'
);

INSERT INTO hostel_rooms (room_name, available_spaces) VALUES
    ('Room A1', 4),
    ('Room B2', 1),
    ('Room C3', 0);

-- STEP 2: IF / ELSIF / ELSE - full, one space left, several spaces
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT room_name, available_spaces FROM hostel_rooms ORDER BY room_id LOOP
        IF r.available_spaces = 0 THEN
            RAISE NOTICE '% : FULL', r.room_name;
        ELSIF r.available_spaces = 1 THEN
            RAISE NOTICE '% : ONE SPACE LEFT', r.room_name;
        ELSE
            RAISE NOTICE '% : SEVERAL SPACES (%)', r.room_name, r.available_spaces;
        END IF;
    END LOOP;
END $$;

-- STEP 3: WHILE (inspection days) and numeric FOR (room checks)
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', d;
        d := d + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Room check %', i;
    END LOOP;
END $$;

-- STEP 4: allocate_room procedure
CREATE OR REPLACE PROCEDURE allocate_room(p_student VARCHAR, p_room_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_avail INT;
BEGIN
    IF p_student IS NULL OR trim(p_student) = '' THEN
        RAISE EXCEPTION 'Invalid input: student number cannot be blank.';
    END IF;

    SELECT available_spaces INTO v_avail
    FROM hostel_rooms WHERE room_id = p_room_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room % does not exist.', p_room_id;
    END IF;

    IF v_avail >= 1 THEN
        UPDATE hostel_rooms SET available_spaces = available_spaces - 1
        WHERE room_id = p_room_id;
        INSERT INTO allocations (student_number, room_id) VALUES (p_student, p_room_id);
        RAISE NOTICE 'Student % allocated to room %.', p_student, p_room_id;
    ELSE
        RAISE NOTICE 'REJECTED: room % is full. Student % not allocated.', p_room_id, p_student;
    END IF;
END $$;

-- STEP 5: two valid allocations + one to a full room
CALL allocate_room('2023001', 1);  -- valid
CALL allocate_room('2023002', 2);  -- valid (takes the last space)
CALL allocate_room('2023003', 3);  -- full room, rejected

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

-- STEP 6: check_out procedure (second call must not free another space)
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_room   INT;
    v_status VARCHAR;
BEGIN
    SELECT room_id, status INTO v_room, v_status
    FROM allocations WHERE allocation_id = p_allocation_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Allocation % does not exist.', p_allocation_id;
    ELSIF v_status = 'COMPLETE' THEN
        RAISE NOTICE 'Allocation % already checked out. No space freed.', p_allocation_id;
    ELSE
        UPDATE allocations SET status = 'COMPLETE' WHERE allocation_id = p_allocation_id;
        UPDATE hostel_rooms SET available_spaces = available_spaces + 1 WHERE room_id = v_room;
        RAISE NOTICE 'Allocation % checked out. One space freed.', p_allocation_id;
    END IF;
END $$;

CALL check_out(1);  -- frees a space
CALL check_out(1);  -- second call: nothing freed

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

-- STEP 7: explicit cursor - full or nearly full rooms
DO $$
DECLARE
    cur_rooms CURSOR FOR
        SELECT room_name, available_spaces FROM hostel_rooms
        WHERE available_spaces <= 1 ORDER BY available_spaces, room_name;
    rec RECORD;
BEGIN
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/nearly full: % (% spaces)', rec.room_name, rec.available_spaces;
    END LOOP;
    CLOSE cur_rooms;
END $$;

-- STEP 8: blank student number, handled with EXCEPTION block
DO $$
BEGIN
    CALL allocate_room('   ', 1);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- STEP 9: final results
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;
