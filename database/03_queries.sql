-- ============================================================
-- Wypożyczalnia książek — zapytania SQL (SELECT / INSERT / DELETE)
-- ============================================================
USE wypozyczalnia_ksiazek;

-- ------------------------------------------------------------
-- 1. SELECT — lista wszystkich książek z autorem i kategorią
-- ------------------------------------------------------------
SELECT
    b.title,
    CONCAT(a.first_name, ' ', a.last_name) AS autor,
    c.name AS kategoria,
    b.publication_year
FROM books b
JOIN authors a    ON b.author_id = a.id
JOIN categories c ON b.category_id = c.id
ORDER BY b.title;

-- ------------------------------------------------------------
-- 2. SELECT — dostępne egzemplarze konkretnej książki
-- ------------------------------------------------------------
SELECT
    b.title,
    co.inventory_number,
    co.status
FROM copies co
JOIN books b ON co.book_id = b.id
WHERE co.status = 'dostepny'
ORDER BY b.title;

-- ------------------------------------------------------------
-- 3. SELECT — aktywne wypożyczenia (jeszcze niezwrócone)
-- ------------------------------------------------------------
SELECT
    l.id AS wypozyczenie_id,
    CONCAT(m.first_name, ' ', m.last_name) AS czytelnik,
    b.title,
    l.loan_date,
    l.due_date
FROM loans l
JOIN copies co ON l.copy_id = co.id
JOIN books b   ON co.book_id = b.id
JOIN members m ON l.member_id = m.id
WHERE l.return_date IS NULL
ORDER BY l.due_date;

-- ------------------------------------------------------------
-- 4. SELECT — wypożyczenia przeterminowane (agregacja + WHERE)
-- ------------------------------------------------------------
SELECT
    CONCAT(m.first_name, ' ', m.last_name) AS czytelnik,
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
-- 5. SELECT — liczba wypożyczeń na czytelnika (GROUP BY)
-- ------------------------------------------------------------
SELECT
    CONCAT(m.first_name, ' ', m.last_name) AS czytelnik,
    COUNT(l.id) AS liczba_wypozyczen
FROM members m
LEFT JOIN loans l ON l.member_id = m.id
GROUP BY m.id, czytelnik
ORDER BY liczba_wypozyczen DESC;

-- ------------------------------------------------------------
-- 6. SELECT — książki, które nigdy nie były wypożyczone (podzapytanie)
-- ------------------------------------------------------------
SELECT b.title
FROM books b
WHERE b.id NOT IN (
    SELECT co.book_id
    FROM copies co
    JOIN loans l ON l.copy_id = co.id
);

-- ------------------------------------------------------------
-- 7. INSERT — dodanie nowego czytelnika
--    (w prawdziwej aplikacji hasło NIGDY nie jest wstawiane wprost —
--    ten przykład tylko ilustruje strukturę zapytania; docelowo
--    rejestracja odbywa się przez endpoint /api/auth/register, który
--    sam hashuje hasło przed zapisem)
-- ------------------------------------------------------------
INSERT INTO members (first_name, last_name, email, phone, password_hash, registration_date)
VALUES ('Jan', 'Kowalczyk', 'jan.kowalczyk@example.com', '600100299', 'PLACEHOLDER_HASH', CURDATE());

-- ------------------------------------------------------------
-- 8. INSERT — nowa książka wraz z egzemplarzem
-- ------------------------------------------------------------
INSERT INTO books (title, isbn, publication_year, author_id, category_id)
VALUES ('Lalka', '9788373265651', 1890, 1, 2);

INSERT INTO copies (book_id, inventory_number, status)
VALUES (LAST_INSERT_ID(), 'INV-0012', 'dostepny');

-- ------------------------------------------------------------
-- 9. INSERT — zarejestrowanie nowego wypożyczenia
-- ------------------------------------------------------------
INSERT INTO loans (copy_id, member_id, loan_date, due_date)
VALUES (7, 6, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 14 DAY));

-- ------------------------------------------------------------
-- 10. DELETE — usunięcie zwróconego, historycznego wypożyczenia
--     (przykład czyszczenia starych, w pełni zamkniętych rekordów)
-- ------------------------------------------------------------
DELETE FROM loans
WHERE return_date IS NOT NULL
  AND return_date < '2020-01-01';

-- ------------------------------------------------------------
-- 11. DELETE — usunięcie czytelnika, który nigdy nic nie wypożyczył
-- ------------------------------------------------------------
DELETE FROM members
WHERE id NOT IN (SELECT DISTINCT member_id FROM loans)
  AND email = 'jan.kowalczyk@example.com';
