-- ============================================================
-- Wypożyczalnia książek — dane przykładowe
-- ============================================================
USE wypozyczalnia_ksiazek;

-- ------------------------------------------------------------
-- Autorzy
-- ------------------------------------------------------------
INSERT INTO authors (first_name, last_name) VALUES
('Andrzej', 'Sapkowski'),
('Olga',    'Tokarczuk'),
('George',  'Orwell'),
('J.K.',    'Rowling'),
('Stanisław','Lem');

-- ------------------------------------------------------------
-- Kategorie
-- ------------------------------------------------------------
INSERT INTO categories (name) VALUES
('Fantastyka'),
('Literatura piękna'),
('Science fiction'),
('Kryminał'),
('Literatura dziecięca');

-- ------------------------------------------------------------
-- Książki
-- ------------------------------------------------------------
INSERT INTO books (title, isbn, publication_year, author_id, category_id) VALUES
('Wiedźmin: Ostatnie życzenie', '9788375780635', 1993, 1, 1),
('Miecz przeznaczenia',         '9788375780659', 1992, 1, 1),
('Bieguni',                     '9788380495001', 2007, 2, 2),
('Rok 1984',                    '9788373372634', 1949, 3, 3),
('Folwark zwierzęcy',           '9788373372627', 1945, 3, 2),
('Harry Potter i Kamień Filozoficzny', '9788380080409', 1997, 4, 5),
('Solaris',                     '9788308067213', 1961, 5, 3),
('Cyberiada',                   '9788308067220', 1965, 5, 3);

-- ------------------------------------------------------------
-- Egzemplarze (niektóre tytuły mają po kilka sztuk)
-- ------------------------------------------------------------
INSERT INTO copies (book_id, inventory_number, status) VALUES
(1, 'INV-0001', 'dostepny'),
(1, 'INV-0002', 'wypozyczony'),
(2, 'INV-0003', 'dostepny'),
(3, 'INV-0004', 'dostepny'),
(4, 'INV-0005', 'wypozyczony'),
(4, 'INV-0006', 'dostepny'),
(5, 'INV-0007', 'dostepny'),
(6, 'INV-0008', 'wypozyczony'),
(6, 'INV-0009', 'dostepny'),
(7, 'INV-0010', 'dostepny'),
(8, 'INV-0011', 'zagubiony');

-- ------------------------------------------------------------
-- Czytelnicy
-- ------------------------------------------------------------
INSERT INTO members (first_name, last_name, email, phone, registration_date) VALUES
('Anna',    'Kowalska', 'anna.kowalska@example.com',   '600100200', '2024-09-01'),
('Piotr',   'Nowak',    'piotr.nowak@example.com',     '600100201', '2024-10-15'),
('Katarzyna','Wiśniewska','katarzyna.w@example.com',   '600100202', '2025-01-20'),
('Marek',   'Wójcik',   'marek.wojcik@example.com',    '600100203', '2025-02-11'),
('Ewa',     'Kaczmarek','ewa.kaczmarek@example.com',   '600100204', '2025-03-05'),
('Tomasz',  'Zieliński','tomasz.zielinski@example.com',NULL,        '2025-04-18');

-- ------------------------------------------------------------
-- Wypożyczenia (aktywne, zwrócone, przeterminowane)
-- ------------------------------------------------------------
-- copy_id=2 (Ostatnie życzenie) wypożyczony przez Annę — aktywne, w terminie
INSERT INTO loans (copy_id, member_id, loan_date, due_date, return_date) VALUES
(2, 1, '2026-06-20', '2026-07-04', NULL);

-- copy_id=5 (Rok 1984) wypożyczony przez Piotra — PRZETERMINOWANE (do testowania funkcji/kar)
INSERT INTO loans (copy_id, member_id, loan_date, due_date, return_date) VALUES
(5, 2, '2026-06-01', '2026-06-15', NULL);

-- copy_id=8 (Harry Potter) wypożyczony przez Katarzynę — aktywne
INSERT INTO loans (copy_id, member_id, loan_date, due_date, return_date) VALUES
(8, 3, '2026-06-25', '2026-07-09', NULL);

-- historia: egzemplarz zwrócony w terminie (Marek pożyczał Bieguni)
INSERT INTO loans (copy_id, member_id, loan_date, due_date, return_date) VALUES
(4, 4, '2026-05-01', '2026-05-15', '2026-05-14');

-- historia: egzemplarz zwrócony po terminie (Ewa pożyczała Solaris)
INSERT INTO loans (copy_id, member_id, loan_date, due_date, return_date) VALUES
(10, 5, '2026-04-10', '2026-04-24', '2026-04-30');
