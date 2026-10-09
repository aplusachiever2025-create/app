<?php
declare(strict_types=1);
// Copy to config.php on the TEST host only. Never commit real credentials.
define('TM_DB_HOST', 'localhost');
define('TM_DB_NAME', 'REPLACE_WITH_TEST_DATABASE');
define('TM_DB_USER', 'REPLACE_WITH_TEST_USER');
define('TM_DB_PASS', 'REPLACE_WITH_TEST_PASSWORD');
define('TM_ALLOWED_ORIGIN', 'https://aplusachiever2025-create.github.io');
define('TM_SESSION_TTL_HOURS', 12);
