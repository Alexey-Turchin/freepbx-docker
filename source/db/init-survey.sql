-- Create DB
CREATE DATABASE asterisksurvey;

-- Create table
CREATE TABLE `survey` (
  `id` int NOT NULL AUTO_INCREMENT,
  `num` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `operator` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `queue` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `valuation` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=398810 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;