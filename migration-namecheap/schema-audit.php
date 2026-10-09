<?php
declare(strict_types=1);

/**
 * CLI-only schema inventory for the Namecheap TEST database.
 * Run over SSH/terminal: php migration-namecheap/schema-audit.php
 * This prints table and column metadata only, never rows or credentials.
 * Do not make this script web-accessible.
 */
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
$config = dirname(__DIR__) . '/config.php';
if (!is_file($config)) {
    fwrite(STDERR, "Missing config.php in the parent directory. Copy config.example.php to config.php and set TEST DB credentials.\n");
    exit(1);
}
require_once $config;
try {
    $pdo = new PDO(
        'mysql:host=' . TM_DB_HOST . ';dbname=' . TM_DB_NAME . ';charset=utf8mb4',
        TM_DB_USER,
        TM_DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
    $tables = $pdo->query(
        'SELECT TABLE_NAME, TABLE_TYPE FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() ORDER BY TABLE_NAME'
    )->fetchAll();
    foreach ($tables as $table) {
        echo "\n## " . $table['TABLE_NAME'] . " (" . $table['TABLE_TYPE'] . ")\n";
        $q = $pdo->prepare(
            'SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT, EXTRA
             FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
             ORDER BY ORDINAL_POSITION'
        );
        $q->execute([$table['TABLE_NAME']]);
        foreach ($q->fetchAll() as $column) {
            printf(
                "- %s | %s | nullable=%s | key=%s | default=%s | extra=%s\n",
                $column['COLUMN_NAME'],
                $column['COLUMN_TYPE'],
                $column['IS_NULLABLE'],
                $column['COLUMN_KEY'] ?: '-',
                $column['COLUMN_DEFAULT'] === null ? 'NULL' : (string)$column['COLUMN_DEFAULT'],
                $column['EXTRA'] ?: '-'
            );
        }
    }
    echo "\nSchema inventory completed. No business rows were read.\n";
} catch (Throwable $e) {
    fwrite(STDERR, "Schema inventory failed. Check database name/user privileges and PHP pdo_mysql. Details: " . $e->getMessage() . "\n");
    exit(1);
}
