-- Create asterisk database
CREATE DATABASE IF NOT EXISTS asterisk;

-- Grant privileges to freepbxuser for asterisk database
GRANT ALL PRIVILEGES ON `asterisk`.* TO 'freepbxuser'@'%';

CREATE DATABASE IF NOT EXISTS asteriskcdrdb;

-- Grant privileges to freepbxuser for asteriskcdrdb database
GRANT ALL PRIVILEGES ON `asteriskcdrdb`.* TO 'freepbxuser'@'%';

FLUSH PRIVILEGES;