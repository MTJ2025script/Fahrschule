-- mtj_fahrschule – vollständiges Schema ohne Syntaxfehler
-- Enthält alle vom Script benötigten Tabellen (bookings, theory, practice, licenses)
-- plus optionale ESX-Lizenztypen. Die Item-Seeds sind unten als sichere, kommentierte Blöcke
-- für beide ESX-Varianten (weight/limit) beigefügt.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- 1) Aktive Buchung pro Spieler (Upsert per PRIMARY KEY(identifier))
CREATE TABLE IF NOT EXISTS `mtj_fahrschule_bookings` (
  `identifier` VARCHAR(64) NOT NULL,                 -- ESX identifier, QBCore citizenid, oder 'src:<id>'
  `category`   VARCHAR(16) NOT NULL,                 -- car|bike|truck|heli|plane
  `token`      VARCHAR(64) NOT NULL,                 -- 32-stelliges Hex (Reserve bis 64)
  `mode`       ENUM('theorie','praxis') NOT NULL DEFAULT 'theorie',
  `expires`    DATETIME NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`),
  KEY `idx_expires` (`expires`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2) Theorie-Ergebnisse (Historie)
CREATE TABLE IF NOT EXISTS `mtj_fahrschule_theory` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `category`   VARCHAR(16) NOT NULL,
  `score_pct`  TINYINT UNSIGNED NOT NULL DEFAULT 0,  -- 0..100
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_identifier_created` (`identifier`, `created_at`),
  KEY `idx_category_created` (`category`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3) Praxis-Ergebnisse (Historie)
CREATE TABLE IF NOT EXISTS `mtj_fahrschule_practice` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier`  VARCHAR(64) NOT NULL,
  `category`    VARCHAR(16) NOT NULL,
  `summary`     TEXT,
  `passed`      TINYINT(1) NOT NULL DEFAULT 0,
  `errors_json` LONGTEXT NULL,                        -- JSON als Text (max. Kompatibilität)
  `created_at`  DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_identifier_created` (`identifier`, `created_at`),
  KEY `idx_category_created` (`category`, `created_at`),
  KEY `idx_passed_created` (`passed`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4) Führerschein-Karte (Upsert per PRIMARY KEY(identifier,category))
CREATE TABLE IF NOT EXISTS `mtj_fahrschule_licenses` (
  `identifier` VARCHAR(64) NOT NULL,
  `category`   VARCHAR(16) NOT NULL,
  `issued_at`  DATE NULL,
  `expires_at` DATE NULL,
  `photo_url`  LONGTEXT NULL,                         -- Data-URL (Base64) oder externe URL
  PRIMARY KEY (`identifier`, `category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5) ESX-Lizenztypen (optional, aber ungefährlich – Tabelle wird nur angelegt, wenn sie fehlt)
CREATE TABLE IF NOT EXISTS `licenses` (
  `type`  VARCHAR(60) NOT NULL,
  `label` VARCHAR(60) NOT NULL,
  PRIMARY KEY (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `licenses` (`type`, `label`) VALUES
('drive',       'Führerschein (PKW)'),
('drive_bike',  'Führerschein (Motorrad)'),
('drive_truck', 'Führerschein (LKW)'),
('boat',        'Bootsführerschein'),
('heli',        'Hubschrauberlizenz'),
('plane',       'Fluglizenz'),
('weapon',      'Waffenlizenz');

-- 6) ESX-Items (Zertifikate) – automatisch kompatibel mit beiden ESX-Schemata
--    Eine gespeicherte Prozedur versucht erst das weight-Schema (ESX Legacy) und dann
--    das limit-Schema (altes ESX). Fehler werden durch CONTINUE HANDLER ignoriert.
--    Falls du ox_inventory nutzt, definiere die Items dort (s. unten) – dieser Block
--    schadet ox_inventory-Servern nicht, da ein fehlendes items-Table ignoriert wird.

DROP PROCEDURE IF EXISTS `mtj_ensure_items`;
DELIMITER $$
CREATE PROCEDURE `mtj_ensure_items`()
BEGIN
    -- Fehler werden ignoriert (fehlende Spalten / Tabelle / Duplikate)
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;

    -- Variante A: ESX Legacy (weight-Spalte)
    INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
    ('cert_theory_pkw',     'Zertifikat Theorie (PKW)',           1, 0, 1),
    ('cert_practice_pkw',   'Zertifikat Praxis (PKW)',            1, 0, 1),
    ('cert_theory_bike',    'Zertifikat Theorie (Motorrad)',      1, 0, 1),
    ('cert_practice_bike',  'Zertifikat Praxis (Motorrad)',       1, 0, 1),
    ('cert_theory_truck',   'Zertifikat Theorie (LKW)',           1, 0, 1),
    ('cert_practice_truck', 'Zertifikat Praxis (LKW)',            1, 0, 1),
    ('cert_theory_heli',    'Zertifikat Theorie (Hubschrauber)',  1, 0, 1),
    ('cert_practice_heli',  'Zertifikat Praxis (Hubschrauber)',   1, 0, 1),
    ('cert_theory_plane',   'Zertifikat Theorie (Flugzeug)',      1, 0, 1),
    ('cert_practice_plane', 'Zertifikat Praxis (Flugzeug)',       1, 0, 1);

    -- Variante B: Altes ESX (limit-Spalte) – wird nur ausgeführt wenn weight fehlt
    INSERT IGNORE INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES
    ('cert_theory_pkw',     'Zertifikat Theorie (PKW)',           1, 0, 1),
    ('cert_practice_pkw',   'Zertifikat Praxis (PKW)',            1, 0, 1),
    ('cert_theory_bike',    'Zertifikat Theorie (Motorrad)',      1, 0, 1),
    ('cert_practice_bike',  'Zertifikat Praxis (Motorrad)',       1, 0, 1),
    ('cert_theory_truck',   'Zertifikat Theorie (LKW)',           1, 0, 1),
    ('cert_practice_truck', 'Zertifikat Praxis (LKW)',            1, 0, 1),
    ('cert_theory_heli',    'Zertifikat Theorie (Hubschrauber)',  1, 0, 1),
    ('cert_practice_heli',  'Zertifikat Praxis (Hubschrauber)',   1, 0, 1),
    ('cert_theory_plane',   'Zertifikat Theorie (Flugzeug)',      1, 0, 1),
    ('cert_practice_plane', 'Zertifikat Praxis (Flugzeug)',       1, 0, 1);
END$$
DELIMITER ;

CALL `mtj_ensure_items`();
DROP PROCEDURE IF EXISTS `mtj_ensure_items`;

-- HINWEIS ox_inventory: Items nicht per SQL, sondern in ox_inventory/data/items.lua eintragen:
-- ['cert_theory_pkw']     = { label = 'Zertifikat Theorie (PKW)',          weight = 0 },
-- ['cert_practice_pkw']   = { label = 'Zertifikat Praxis (PKW)',           weight = 0 },
-- ['cert_theory_bike']    = { label = 'Zertifikat Theorie (Motorrad)',     weight = 0 },
-- ['cert_practice_bike']  = { label = 'Zertifikat Praxis (Motorrad)',      weight = 0 },
-- ['cert_theory_truck']   = { label = 'Zertifikat Theorie (LKW)',          weight = 0 },
-- ['cert_practice_truck'] = { label = 'Zertifikat Praxis (LKW)',           weight = 0 },
-- ['cert_theory_heli']    = { label = 'Zertifikat Theorie (Hubschrauber)', weight = 0 },
-- ['cert_practice_heli']  = { label = 'Zertifikat Praxis (Hubschrauber)',  weight = 0 },
-- ['cert_theory_plane']   = { label = 'Zertifikat Theorie (Flugzeug)',     weight = 0 },
-- ['cert_practice_plane'] = { label = 'Zertifikat Praxis (Flugzeug)',      weight = 0 },