CREATE TABLE IF NOT EXISTS `agents_new` (
  `id` mediumint NOT NULL AUTO_INCREMENT,
  `agent` char(64) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;