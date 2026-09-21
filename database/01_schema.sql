-- ============================================================
-- Wypożyczalnia książek — schemat bazy danych
-- Silnik: MySQL 8.x
-- Poziom projektu: 1 (baza danych)
-- ============================================================

DROP DATABASE IF EXISTS wypozyczalnia_ksiazek;
CREATE DATABASE wypozyczalnia_ksiazek CHARACTER SET utf8mb4 COLLATE utf8mb4_polish_ci;
USE wypozyczalnia_ksiazek;

-- ------------------------------------------------------------
-- Tabela: authors (autorzy)
-- ------------------------------------------------------------
CREATE TABLE authors (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Tabela: categories (kategorie/gatunki książek)
-- ------------------------------------------------------------
CREATE TABLE categories (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    name    VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Tabela: books (tytuły książek — dane bibliograficzne)
-- ------------------------------------------------------------
CREATE TABLE books (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    title               VARCHAR(200) NOT NULL,
    isbn                VARCHAR(20)  NOT NULL UNIQUE,
    publication_year    SMALLINT     NOT NULL,
    author_id           INT          NOT NULL,
    category_id         INT          NOT NULL,
    CONSTRAINT fk_books_author
        FOREIGN KEY (author_id) REFERENCES authors(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_books_category
        FOREIGN KEY (category_id) REFERENCES categories(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Tabela: copies (fizyczne egzemplarze danego tytułu)
-- ------------------------------------------------------------
CREATE TABLE copies (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    book_id             INT NOT NULL,
    inventory_number    VARCHAR(20) NOT NULL UNIQUE,
    status              ENUM('dostepny', 'wypozyczony', 'zagubiony') NOT NULL DEFAULT 'dostepny',
    CONSTRAINT fk_copies_book
        FOREIGN KEY (book_id) REFERENCES books(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Tabela: members (czytelnicy)
-- ------------------------------------------------------------
CREATE TABLE members (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    first_name          VARCHAR(50)  NOT NULL,
    last_name           VARCHAR(50)  NOT NULL,
    email               VARCHAR(100) NOT NULL UNIQUE,
    phone               VARCHAR(20),
    registration_date   DATE NOT NULL DEFAULT (CURRENT_DATE)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Tabela: loans (wypożyczenia)
-- ------------------------------------------------------------
CREATE TABLE loans (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    copy_id         INT  NOT NULL,
    member_id       INT  NOT NULL,
    loan_date       DATE NOT NULL DEFAULT (CURRENT_DATE),
    due_date        DATE NOT NULL,
    return_date     DATE NULL,
    CONSTRAINT fk_loans_copy
        FOREIGN KEY (copy_id) REFERENCES copies(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_loans_member
        FOREIGN KEY (member_id) REFERENCES members(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_loans_dates
        CHECK (due_date >= loan_date)
) ENGINE=InnoDB;

-- Indeksy przyspieszające typowe wyszukiwania
CREATE INDEX idx_loans_member ON loans(member_id);
CREATE INDEX idx_loans_copy   ON loans(copy_id);
CREATE INDEX idx_books_author ON books(author_id);
CREATE INDEX idx_books_category ON books(category_id);
