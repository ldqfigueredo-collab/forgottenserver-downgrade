function onUpdateDatabase()
	print("> Updating database to version 31 (house_transfers)")
	db.query([[
		CREATE TABLE IF NOT EXISTS `house_transfers` (
		  `house_id` int NOT NULL,
		  `from_guid` int NOT NULL,
		  `to_guid` int NOT NULL,
		  `executes_at` int unsigned NOT NULL,
		  PRIMARY KEY (`house_id`),
		  FOREIGN KEY (`house_id`) REFERENCES `houses`(`id`) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8;
	]])
	return true
end
