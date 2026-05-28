CREATE TABLE `queues_new` (
  `id` mediumint NOT NULL AUTO_INCREMENT,
  `queuename` char(64) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;