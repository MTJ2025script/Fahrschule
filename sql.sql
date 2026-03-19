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

-- 6) ESX-Items (Zertifikate) – Wähle GENAU EINEN der beiden Blöcke und entferne die Kommentarzeichen.
--    Lass die Blöcke KOMMENTIERT, wenn du ox_inventory nutzt oder Items bereits definiert sind.

-- [VARIANTE A – ESX Legacy (weight-Schema)]
-- INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
-- ('cert_theory_pkw',      'Zertifikat Theorie (PKW)',            1, 0, 1),
-- ('cert_practice_pkw',    'Zertifikat Praxis (PKW)',             1, 0, 1),
-- ('cert_theory_bike',     'Zertifikat Theorie (Motorrad)',       1, 0, 1),
-- ('cert_practice_bike',   'Zertifikat Praxis (Motorrad)',        1, 0, 1),
-- ('cert_theory_truck',    'Zertifikat Theorie (LKW)',            1, 0, 1),
-- ('cert_practice_truck',  'Zertifikat Praxis (LKW)',             1, 0, 1),
-- ('cert_theory_heli',     'Zertifikat Theorie (Hubschrauber)',   1, 0, 1),
-- ('cert_practice_heli',   'Zertifikat Praxis (Hubschrauber)',    1, 0, 1),
-- ('cert_theory_plane',    'Zertifikat Theorie (Flugzeug)',       1, 0, 1),
-- ('cert_practice_plane',  'Zertifikat Praxis (Flugzeug)',        1, 0, 1);

-- [VARIANTE B – Altes ESX (limit-Schema)]
-- INSERT IGNORE INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES
-- ('cert_theory_pkw',      'Zertifikat Theorie (PKW)',            1, 0, 1),
-- ('cert_practice_pkw',    'Zertifikat Praxis (PKW)',             1, 0, 1),
-- ('cert_theory_bike',     'Zertifikat Theorie (Motorrad)',       1, 0, 1),
-- ('cert_practice_bike',   'Zertifikat Praxis (Motorrad)',        1, 0, 1),
-- ('cert_theory_truck',    'Zertifikat Theorie (LKW)',            1, 0, 1),
-- ('cert_practice_truck',  'Zertifikat Praxis (LKW)',             1, 0, 1),
-- ('cert_theory_heli',     'Zertifikat Theorie (Hubschrauber)',   1, 0, 1),
-- ('cert_practice_heli',   'Zertifikat Praxis (Hubschrauber)',    1, 0, 1),
-- ('cert_theory_plane',    'Zertifikat Theorie (Flugzeug)',       1, 0, 1),
-- ('cert_practice_plane',  'Zertifikat Praxis (Flugzeug)',        1, 0, 1);

-- HINWEIS:
-- - Items-Block A oder B nur ausführen, wenn er zu deinem ESX-Schema passt.
-- - Falls du ox_inventory nutzt, definiere die Items in ox_inventory/data/items.lua statt per SQL.