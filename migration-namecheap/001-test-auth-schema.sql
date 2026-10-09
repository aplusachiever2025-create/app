-- TEST DATABASE ONLY. These prefixed tables do not replace existing production tables.
CREATE TABLE IF NOT EXISTS tm_admin_users (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 username VARCHAR(190) NOT NULL UNIQUE,
 display_name VARCHAR(190) NOT NULL DEFAULT '',
 password_hash VARCHAR(255) NOT NULL,
 active TINYINT(1) NOT NULL DEFAULT 1,
 last_login_at DATETIME NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_admin_sessions (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 admin_user_id BIGINT UNSIGNED NOT NULL,
 token_hash CHAR(64) NOT NULL UNIQUE,
 expires_at DATETIME NOT NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT fk_tm_admin_sessions_user FOREIGN KEY (admin_user_id)
   REFERENCES tm_admin_users(id) ON DELETE CASCADE,
 INDEX idx_tm_admin_sessions_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
