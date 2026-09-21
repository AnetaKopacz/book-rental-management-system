-- ============================================================
-- Wypożyczalnia książek — elementy zaawansowane
-- (widok, funkcja, procedury składowane)
--
-- Triggery (trg_loans_after_insert, trg_loans_after_update)
-- zostały wydzielone do osobnego pliku: 05_triggery.sql
-- Uruchom go PO tym pliku, żeby procedury poniżej działały
-- z automatyczną aktualizacją statusu egzemplarza.
-- ============================================================
USE wypozyczalnia_ksiazek;

-- Na wypadek ponownego uruchamiania tego pliku — usuwamy stare
-- wersje obiektów, żeby uniknąć błędu "already exists"
-- (CREATE PROCEDURE i CREATE FUNCTION, w przeciwieństwie do
-- CREATE OR REPLACE VIEW, nie nadpisują istniejącego obiektu same z siebie).
DROP FUNCTION IF EXISTS oblicz_kare;
DROP PROCEDURE IF EXISTS wypozycz_ksiazke;
DROP PROCEDURE IF EXISTS zwroc_ksiazke;

-- ------------------------------------------------------------
-- WIDOK: aktywne wypożyczenia przeterminowane
-- Przydatny np. do panelu bibliotekarza — kto ma zwrócić książkę
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_wypozyczenia_przeterminowane AS
SELECT
    l.id            AS loan_id,
    m.id            AS member_id,
    CONCAT(m.first_name, ' ', m.last_name) AS czytelnik,
    m.email,
    b.title,
    l.due_date,
    DATEDIFF(CURDATE(), l.due_date) AS dni_po_terminie
FROM loans l
JOIN copies co ON l.copy_id = co.id
JOIN books b   ON co.book_id = b.id
JOIN members m ON l.member_id = m.id
WHERE l.return_date IS NULL
  AND l.due_date < CURDATE();


-- ------------------------------------------------------------
-- FUNKCJA: oblicz_kare
-- Liczy karę za przetrzymanie książki (0.50 zł za dzień zwłoki).
-- Działa zarówno dla wypożyczeń aktywnych, jak i już zwróconych.
-- ------------------------------------------------------------
DELIMITER //

CREATE FUNCTION oblicz_kare(p_loan_id INT)
RETURNS DECIMAL(6,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_due_date DATE;
    DECLARE v_return_date DATE;
    DECLARE v_dni_zwloki INT;
    DECLARE v_stawka DECIMAL(4,2) DEFAULT 0.50;

    SELECT due_date, return_date
    INTO v_due_date, v_return_date
    FROM loans
    WHERE id = p_loan_id;

    IF v_return_date IS NOT NULL THEN
        -- wypożyczenie zamknięte: liczymy zwłokę względem daty zwrotu
        SET v_dni_zwloki = DATEDIFF(v_return_date, v_due_date);
    ELSE
        -- wypożyczenie wciąż aktywne: liczymy zwłokę do dziś
        SET v_dni_zwloki = DATEDIFF(CURDATE(), v_due_date);
    END IF;

    IF v_dni_zwloki <= 0 THEN
        RETURN 0.00;
    END IF;

    RETURN v_dni_zwloki * v_stawka;
END //

DELIMITER ;

-- Przykład użycia:
-- SELECT id, oblicz_kare(id) AS kara FROM loans;


-- ------------------------------------------------------------
-- PROCEDURA: wypozycz_ksiazke
-- Rejestruje wypożyczenie egzemplarza, o ile jest on dostępny.
-- Jeśli egzemplarz jest zajęty/zagubiony — zwraca błąd (SIGNAL).
-- ------------------------------------------------------------
DELIMITER //

CREATE PROCEDURE wypozycz_ksiazke(
    IN p_copy_id INT,
    IN p_member_id INT,
    IN p_dni_wypozyczenia INT
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_loan_id INT;

    SELECT status INTO v_status
    FROM copies
    WHERE id = p_copy_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Egzemplarz o podanym id nie istnieje.';
    ELSEIF v_status <> 'dostepny' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ten egzemplarz nie jest obecnie dostępny.';
    ELSE
        INSERT INTO loans (copy_id, member_id, loan_date, due_date)
        VALUES (p_copy_id, p_member_id, CURDATE(),
                DATE_ADD(CURDATE(), INTERVAL p_dni_wypozyczenia DAY));
        -- status egzemplarza zostanie zaktualizowany automatycznie przez trigger poniżej

        SET v_loan_id = LAST_INSERT_ID();

        -- Pełny komunikat zwrotny widoczny w DBeaver jako normalny wynik SELECT-a
        SELECT
            m.id            AS id_czytelnika,
            b.id            AS id_ksiazki,
            b.title         AS tytul,
            l.loan_date     AS data_wypozyczenia,
            p_dni_wypozyczenia AS na_ile_dni,
            l.due_date      AS termin_zwrotu,
            'Wypożyczenie zarejestrowane pomyślnie.' AS komentarz
        FROM loans l
        JOIN copies co ON l.copy_id = co.id
        JOIN books b   ON co.book_id = b.id
        JOIN members m ON l.member_id = m.id
        WHERE l.id = v_loan_id;
    END IF;
END //

DELIMITER ;

-- Przykład użycia:
-- CALL wypozycz_ksiazke(3, 2, 14);


-- ------------------------------------------------------------
-- PROCEDURA: zwroc_ksiazke
-- Zamyka wypożyczenie (ustawia return_date).
-- ------------------------------------------------------------
DELIMITER //

CREATE PROCEDURE zwroc_ksiazke(IN p_loan_id INT)
BEGIN
    DECLARE v_rows INT;
    DECLARE v_exists INT;

    UPDATE loans
    SET return_date = CURDATE()
    WHERE id = p_loan_id
      AND return_date IS NULL;
    -- status egzemplarza zostanie zaktualizowany automatycznie przez trigger poniżej

    SET v_rows = ROW_COUNT();

    SELECT COUNT(*) INTO v_exists FROM loans WHERE id = p_loan_id;

    IF v_exists = 0 THEN
        SELECT
            NULL AS id_czytelnika,
            NULL AS id_ksiazki,
            NULL AS tytul,
            NULL AS data_wypozyczenia,
            NULL AS termin_zwrotu,
            NULL AS data_zwrotu,
            'Nie znaleziono wypożyczenia o podanym id.' AS komentarz;
    ELSE
        SELECT
            m.id            AS id_czytelnika,
            b.id            AS id_ksiazki,
            b.title         AS tytul,
            l.loan_date     AS data_wypozyczenia,
            l.due_date      AS termin_zwrotu,
            l.return_date   AS data_zwrotu,
            IF(v_rows = 1,
               'Zwrot zarejestrowany pomyślnie.',
               'Wypożyczenie było już wcześniej zwrócone.') AS komentarz
        FROM loans l
        JOIN copies co ON l.copy_id = co.id
        JOIN books b   ON co.book_id = b.id
        JOIN members m ON l.member_id = m.id
        WHERE l.id = p_loan_id;
    END IF;
END //

DELIMITER ;

-- Przykład użycia:
-- CALL zwroc_ksiazke(1);

-- Uwaga: bez wykonania 05_triggery.sql powyższe dwie procedury
-- nadal DZIAŁAJĄ (zarejestrują/zamkną wypożyczenie), ale status
-- egzemplarza w tabeli copies NIE zaktualizuje się automatycznie
-- — to właśnie robotę triggerów z 05_triggery.sql.
