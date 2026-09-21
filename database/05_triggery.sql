-- ============================================================
-- Wypożyczalnia książek — TRIGGERY
-- ============================================================
-- Ten plik zawiera te same triggery co 04_advanced.sql,
-- wydzielone osobno i opisane krok po kroku — do nauki/prezentacji.
--
-- Cel triggerów: automatyczne pilnowanie statusu egzemplarza
-- (copies.status), żeby nikt nie musiał robić tego ręcznie
-- w aplikacji ani zapomnieć o aktualizacji.
--
-- Wymaga wcześniej wykonanego 01_schema.sql (i najlepiej też
-- 02_data.sql, żeby było na czym testować).
-- ============================================================
USE wypozyczalnia_ksiazek;

-- Na wypadek ponownego uruchamiania tego pliku — usuwamy stare
-- wersje triggerów, żeby uniknąć błędu "already exists".
DROP TRIGGER IF EXISTS trg_loans_after_insert;
DROP TRIGGER IF EXISTS trg_loans_after_update;

-- ------------------------------------------------------------
-- TRIGGER 1: trg_loans_after_insert
--
-- Kiedy się odpala:  AFTER INSERT ON loans
--                     (czyli zaraz PO tym, jak nowy wiersz
--                      wypożyczenia zostanie dodany do tabeli)
--
-- Co robi:            Ustawia status egzemplarza (copies.status),
--                      który właśnie ktoś wypożyczył, na
--                      'wypozyczony'.
--
-- Dlaczego to wygodne: Nie trzeba pamiętać o dwóch osobnych
--                      zapytaniach (INSERT do loans + UPDATE do
--                      copies) — wystarczy jeden INSERT do loans,
--                      a baza sama dopilnuje reszty.
--
-- NEW.copy_id          W triggerach AFTER INSERT słowo NEW
--                      odnosi się do wiersza, który właśnie
--                      został dodany. NEW.copy_id to wartość
--                      kolumny copy_id z TEGO nowego wiersza.
-- ------------------------------------------------------------
DELIMITER //

CREATE TRIGGER trg_loans_after_insert
AFTER INSERT ON loans
FOR EACH ROW
BEGIN
    UPDATE copies
    SET status = 'wypozyczony'
    WHERE id = NEW.copy_id;
END //

DELIMITER ;


-- ------------------------------------------------------------
-- TRIGGER 2: trg_loans_after_update
--
-- Kiedy się odpala:  AFTER UPDATE ON loans
--                     (czyli zaraz PO każdej zmianie w istniejącym
--                      wierszu tabeli loans — np. gdy procedura
--                      zwroc_ksiazke() ustawia return_date)
--
-- Co robi:            Sprawdza, czy TĄ konkretną zmianą było
--                      właśnie ustawienie daty zwrotu (czyli
--                      zamknięcie wypożyczenia) — jeśli tak,
--                      ustawia egzemplarz z powrotem na 'dostepny'.
--
-- OLD vs NEW:          W triggerach AFTER UPDATE mamy dostęp
--                      do dwóch wersji wiersza:
--                        OLD.* — wartości SPRZED zmiany
--                        NEW.* — wartości PO zmianie
--                      Dzięki porównaniu OLD.return_date z
--                      NEW.return_date trigger wie, że to jest
--                      MOMENT zwrotu (a nie np. jakaś inna,
--                      przypadkowa aktualizacja wiersza loans).
-- ------------------------------------------------------------
DELIMITER //

CREATE TRIGGER trg_loans_after_update
AFTER UPDATE ON loans
FOR EACH ROW
BEGIN
    IF NEW.return_date IS NOT NULL AND OLD.return_date IS NULL THEN
        UPDATE copies
        SET status = 'dostepny'
        WHERE id = NEW.copy_id;
    END IF;
END //

DELIMITER ;


-- ============================================================
-- JAK PRZETESTOWAĆ (wykonuj pojedynczo, Ctrl+Enter, bez średnika
-- na końcu, żeby DBeaver nie doklejał LIMIT po średniku):
-- ============================================================


-- ============================================================
-- 0) WSZYSTKIE egzemplarze wszystkich książek
--    Pokazuje KAŻDĄ fizyczną sztukę osobno, z jej własnym statusem.
-- ============================================================
SELECT
    co.id AS copy_id,
    b.id AS book_id,
    b.title,
    co.inventory_number,
    co.status
FROM copies co
JOIN books b ON co.book_id = b.id
ORDER BY b.title, co.id;


-- ============================================================
-- 1) Status JEDNEGO konkretnego egzemplarza (po copy_id)
--    + ile łącznie wolnych sztuk ma cały ten tytuł.
-- ============================================================
SELECT
    co.id AS copy_id,
    b.title,
    CONCAT(a.first_name, ' ', a.last_name) AS autor,
    co.status AS status_tego_egzemplarza,
    (SELECT COUNT(*) FROM copies WHERE book_id = b.id AND status = 'dostepny') AS dostepne_sztuki_lacznie
FROM copies co
JOIN books b ON co.book_id = b.id
JOIN authors a ON b.author_id = a.id
WHERE co.id = 12;


-- ============================================================
-- 2) Zbiorcze zestawienie WSZYSTKICH tytułów
--    (ile egzemplarzy ma każda książka i ile jest wolnych)
--    Tu NIE ma pojedynczych copy_id — to jest widok "na poziomie tytułu".
-- ============================================================
SELECT
    b.id AS book_id,
    b.title,
    CONCAT(a.first_name, ' ', a.last_name) AS autor,
    COUNT(co.id) AS wszystkie_egzemplarze,
    SUM(CASE WHEN co.status = 'dostepny' THEN 1 ELSE 0 END) AS dostepne_sztuki
FROM books b
JOIN authors a ON b.author_id = a.id
LEFT JOIN copies co ON co.book_id = b.id
GROUP BY b.id, b.title, autor
ORDER BY autor;


-- ============================================================
-- 3) WYPOŻYCZ konkretny egzemplarz (wywoła trigger nr 1: status -> 'wypozyczony')
--    Parametry procedury: (copy_id, member_id, liczba_dni)
--    UWAGA: pierwszy parametr to copy_id (egzemplarz), NIE id książki!
-- ============================================================
CALL wypozycz_ksiazke(9, 3, 14);


-- ============================================================
-- 4) Sprawdź status TEGO SAMEGO egzemplarza po wypożyczeniu
--    Oczekiwany wynik: 'wypozyczony'
-- ============================================================
SELECT id, status FROM copies WHERE id = 9;


-- ============================================================
-- 4a) Znajdź loan_id nowo utworzonego wypożyczenia
--     (potrzebne do kroku 5 — zwrotu)
-- ============================================================
SELECT id, copy_id, member_id, loan_date, due_date
FROM loans
ORDER BY id DESC
LIMIT 1;


-- ============================================================
-- 5) ZWRÓĆ książkę (wywoła trigger nr 2: status -> 'dostepny')
--    Parametr procedury: loan_id (NIE copy_id!) — wstaw id z kroku 4a
-- ============================================================
CALL zwroc_ksiazke(7);


-- ============================================================
-- 6) Sprawdź status egzemplarza po zwrocie
--    Oczekiwany wynik: z powrotem 'dostepny'
-- ============================================================
SELECT id, status FROM copies WHERE id = 9;


-- ============================================================
-- 7) Historia wszystkich wypożyczeń — tylko AKTYWNE (jeszcze niezwrócone)
--    Kolumna status_wypozyczenia rozróżnia: aktywne / przeterminowane / zwrocone
-- ============================================================
SELECT
    l.id AS loan_id,
    CONCAT(m.first_name, ' ', m.last_name) AS czytelnik,
    b.title,
    co.id AS copy_id,
    co.inventory_number,
    l.loan_date,
    l.due_date,
    l.return_date,
    CASE
        WHEN l.return_date IS NOT NULL THEN 'zwrocone'
        WHEN l.due_date < CURDATE() THEN 'przeterminowane'
        ELSE 'aktywne'
    END AS status_wypozyczenia
FROM loans l
JOIN copies co  ON l.copy_id = co.id
JOIN books b    ON co.book_id = b.id
JOIN members m  ON l.member_id = m.id
WHERE l.return_date IS NULL
ORDER BY l.loan_date DESC;

-- ============================================================
-- 8) Ile razy KAŻDA książka była wypożyczona (licząc wszystkie
--    egzemplarze tego tytułu łącznie — historia + aktywne)
-- ============================================================
SELECT
    b.id AS book_id,
    b.title,
    COUNT(l.id) AS liczba_wypozyczen
FROM books b
LEFT JOIN copies co ON co.book_id = b.id
LEFT JOIN loans l   ON l.copy_id = co.id
GROUP BY b.id, b.title
ORDER BY liczba_wypozyczen DESC;


-- ============================================================
-- 9) Ile razy KONKRETNA książka była wypożyczona (np. Harry Potter)
--    Podmień tekst w LIKE na tytuł, który Cię interesuje.
-- ============================================================
SELECT
    b.title,
    COUNT(l.id) AS liczba_wypozyczen
FROM books b
LEFT JOIN copies co ON co.book_id = b.id
LEFT JOIN loans l   ON l.copy_id = co.id
WHERE b.title LIKE '%Harry Potter%'
GROUP BY b.id, b.title;


-- ============================================================
-- 10) Ile książek ŁĄCZNIE wypożyczył dany czytelnik (po id)
--     Podmień 4 na id interesującego Cię czytelnika.
-- ============================================================
SELECT
    CONCAT(m.first_name, ' ', m.last_name) AS czytelnik,
    COUNT(l.id) AS liczba_wypozyczen
FROM members m
LEFT JOIN loans l ON l.member_id = m.id
WHERE m.id = 4
GROUP BY m.id, czytelnik;


-- ============================================================
-- 11) Szczegółowa historia wypożyczeń KONKRETNEGO czytelnika (po id)
--     tytuł, data wypożyczenia, zwrot, status, kara
--     Wymaga funkcji oblicz_kare() z 04_advanced.sql.
-- ============================================================
SELECT
    b.title,
    l.loan_date,
    l.due_date,
    l.return_date,
    CASE
        WHEN l.return_date IS NULL AND l.due_date < CURDATE() THEN 'przeterminowane'
        WHEN l.return_date IS NULL THEN 'aktywne'
        ELSE 'zwrocone'
    END AS status_wypozyczenia,
    oblicz_kare(l.id) AS kara_zl
FROM loans l
JOIN copies co ON l.copy_id = co.id
JOIN books b   ON co.book_id = b.id
JOIN members m ON l.member_id = m.id
WHERE m.id = 5
ORDER BY l.loan_date DESC;

-- ============================================================
-- 12) TOP 5 najbardziej aktywnych czytelników (najwięcej wypożyczeń)
-- ============================================================
SELECT
    CONCAT(m.first_name, ' ', m.last_name) AS czytelnik,
    COUNT(l.id) AS liczba_wypozyczen
FROM members m
LEFT JOIN loans l ON l.member_id = m.id
GROUP BY m.id, czytelnik
ORDER BY liczba_wypozyczen DESC
LIMIT 5;


-- ============================================================
-- 13) Suma należnych kar dla każdego czytelnika, który ma karę > 0
--     Łączy funkcję oblicz_kare() z agregacją SUM (wymaga 04_advanced.sql)
-- ============================================================
SELECT
    CONCAT(m.first_name, ' ', m.last_name) AS czytelnik,
    SUM(oblicz_kare(l.id)) AS suma_kar_zl
FROM loans l
JOIN members m ON l.member_id = m.id
GROUP BY m.id, czytelnik
HAVING SUM(oblicz_kare(l.id)) > 0
ORDER BY suma_kar_zl DESC;


-- ============================================================
-- 14) Najpopularniejsza KATEGORIA książek (nie pojedynczy tytuł,
--     tylko cały gatunek — np. "Fantastyka" vs "Kryminał")
-- ============================================================
SELECT
    c.name AS kategoria,
    COUNT(l.id) AS liczba_wypozyczen
FROM categories c
JOIN books b ON b.category_id = c.id
JOIN copies co ON co.book_id = b.id
LEFT JOIN loans l ON l.copy_id = co.id
GROUP BY c.id, c.name
ORDER BY liczba_wypozyczen DESC;


-- ============================================================
-- 15) Średni czas trzymania książki przez czytelników (w dniach)
--     Liczone tylko dla wypożyczeń już zwróconych (return_date IS NOT NULL)
-- ============================================================
SELECT
    ROUND(AVG(DATEDIFF(return_date, loan_date)), 1) AS sredni_czas_wypozyczenia_dni
FROM loans
WHERE return_date IS NOT NULL;

show triggers

