<?php
// ⚠️  SECURITY NOTICE:
// This file contains database credentials.
// Before deploying to a production server:
//   1. Replace credentials with environment variables or a secrets manager
//   2. Add config/db.php to .gitignore
//   3. Never commit real production passwords to version control

/**
 * ═══════════════════════════════════════════════════════════
 * DATABASE CONFIGURATION & CONNECTION
 * ═══════════════════════════════════════════════════════════
 * Establishes PDO connection to MySQL with singleton pattern
 */

// Set database credentials for connecting to the MySQL server.
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', '');
define('DB_NAME', 'horizon_academy');

/**
 * Get database connection (singleton pattern) - returns the same connection each time it's called.
 */
function getDB(): PDO {
    static $pdo = null;
    
    // Create database connection only once and reuse it for all queries to save resources.
    if ($pdo === null) {
        try {
            // Connect to MySQL database with UTF-8 encoding, fetch results as arrays, and use real prepared statements.
            $pdo = new PDO(
                'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
                DB_USER,
                DB_PASS,
                [
                    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES   => false,
                ]
            );
        } catch (PDOException $e) {
            // If database connection fails, show an error message to help diagnose the problem.
            http_response_code(500);
            die('<h2 style="font-family:sans-serif;color:#c0392b;">Database connection failed.</h2><pre>' . htmlspecialchars($e->getMessage()) . '</pre>');
        }
    }
    
    return $pdo;
}
