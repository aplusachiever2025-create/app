-- SG Tutor Match migration staging schema for Namecheap MySQL 8.x
-- SAFETY: all tables use the tm_ prefix and are isolated from any existing tables.
-- Import this only into the dedicated staging database first. Do not run on production
-- until a backup, data mapping, and end-to-end verification are complete.

CREATE TABLE IF NOT EXISTS tm_admin_users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(190) NOT NULL UNIQUE,
  display_name VARCHAR(190) NOT NULL DEFAULT '',
  password_hash VARCHAR(255) NOT NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  last_login_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_admin_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  admin_user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tm_admin_sessions_user FOREIGN KEY (admin_user_id)
    REFERENCES tm_admin_users(id) ON DELETE CASCADE,
  INDEX idx_tm_admin_sessions_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_platform_admins (
  admin_user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
  display_name VARCHAR(190) NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tm_platform_admin_user FOREIGN KEY (admin_user_id)
    REFERENCES tm_admin_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_parent_requests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  level VARCHAR(120) NOT NULL,
  subject VARCHAR(190) NOT NULL,
  lang VARCHAR(120) NULL,
  postcode VARCHAR(30) NULL,
  region VARCHAR(190) NULL,
  address TEXT NULL,
  budget VARCHAR(120) NULL,
  freq VARCHAR(120) NULL,
  duration VARCHAR(120) NULL,
  timeslot TEXT NULL,
  goal VARCHAR(190) NULL,
  gender VARCHAR(60) NULL,
  mode VARCHAR(120) NULL,
  tutortype VARCHAR(120) NULL,
  notes TEXT NULL,
  contact_name VARCHAR(190) NULL,
  contact_phone VARCHAR(80) NULL,
  contact_email VARCHAR(254) NULL,
  contact_wechat VARCHAR(190) NULL,
  request_status ENUM('active','closed','removed') NOT NULL DEFAULT 'active',
  removed_at DATETIME NULL,
  removed_reason TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_tm_parent_created (created_at),
  INDEX idx_tm_parent_status (request_status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_tutor_profiles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(190) NOT NULL,
  scopes JSON NOT NULL,
  level VARCHAR(190) NULL,
  cred TEXT NULL,
  rate VARCHAR(120) NULL,
  gender VARCHAR(60) NULL,
  mode VARCHAR(120) NULL,
  lang VARCHAR(120) NULL,
  exp TEXT NULL,
  trial VARCHAR(120) NULL,
  regions JSON NOT NULL,
  timeslots JSON NOT NULL,
  bio TEXT NULL,
  whatsapp VARCHAR(100) NULL,
  contact_email VARCHAR(254) NULL,
  contact_phone VARCHAR(80) NULL,
  tutor_status ENUM('active','removed') NOT NULL DEFAULT 'active',
  removed_at DATETIME NULL,
  removed_reason TEXT NULL,
  resume_storage_key VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_tm_tutor_created (created_at),
  INDEX idx_tm_tutor_status (tutor_status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_match_interests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  parent_request_id BIGINT UNSIGNED NOT NULL,
  tutor_id BIGINT UNSIGNED NOT NULL,
  interested_by ENUM('parent','tutor') NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tm_interest_pair (parent_request_id, tutor_id, interested_by),
  INDEX idx_tm_interest_parent (parent_request_id, created_at),
  INDEX idx_tm_interest_tutor (tutor_id, created_at),
  CONSTRAINT fk_tm_interest_parent FOREIGN KEY (parent_request_id)
    REFERENCES tm_parent_requests(id) ON DELETE CASCADE,
  CONSTRAINT fk_tm_interest_tutor FOREIGN KEY (tutor_id)
    REFERENCES tm_tutor_profiles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_match_cases (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  parent_request_id BIGINT UNSIGNED NOT NULL,
  tutor_id BIGINT UNSIGNED NOT NULL,
  status ENUM('new','both_interested','contacting','trial','confirmed','not_concluded','cancelled') NOT NULL DEFAULT 'new',
  parent_interested_at DATETIME NULL,
  tutor_interested_at DATETIME NULL,
  last_contacted_at DATETIME NULL,
  confirmed_at DATETIME NULL,
  confirmed_by BIGINT UNSIGNED NULL,
  not_concluded_reason VARCHAR(190) NULL,
  not_concluded_note TEXT NULL,
  hourly_rate DECIMAL(10,2) NULL,
  lesson_duration_hours DECIMAL(4,2) NULL,
  lessons_per_week DECIMAL(4,2) NULL,
  first_lesson_date DATE NULL,
  commission_amount DECIMAL(10,2) NULL,
  commission_status ENUM('pending','invoiced','paid','waived','cancelled') NOT NULL DEFAULT 'pending',
  platform_note TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tm_case_pair (parent_request_id, tutor_id),
  INDEX idx_tm_case_status (status, created_at),
  INDEX idx_tm_case_tutor (tutor_id, created_at),
  CONSTRAINT fk_tm_case_parent FOREIGN KEY (parent_request_id)
    REFERENCES tm_parent_requests(id) ON DELETE CASCADE,
  CONSTRAINT fk_tm_case_tutor FOREIGN KEY (tutor_id)
    REFERENCES tm_tutor_profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_tm_case_confirmed_by FOREIGN KEY (confirmed_by)
    REFERENCES tm_admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_tutor_internal_scores (
  tutor_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
  level ENUM('金牌','银牌','铜牌','普通','观察') NOT NULL DEFAULT '普通',
  recommendations INT UNSIGNED NOT NULL DEFAULT 0,
  interests INT UNSIGNED NOT NULL DEFAULT 0,
  confirmed_deals INT UNSIGNED NOT NULL DEFAULT 0,
  not_concluded INT UNSIGNED NOT NULL DEFAULT 0,
  cancellations INT UNSIGNED NOT NULL DEFAULT 0,
  score DECIMAL(8,2) NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_tm_tutor_score FOREIGN KEY (tutor_id)
    REFERENCES tm_tutor_profiles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_parent_internal_scores (
  parent_request_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
  level ENUM('黄质','银质','铜质','普通','观察') NOT NULL DEFAULT '普通',
  requests INT UNSIGNED NOT NULL DEFAULT 0,
  interests INT UNSIGNED NOT NULL DEFAULT 0,
  confirmed_deals INT UNSIGNED NOT NULL DEFAULT 0,
  not_concluded INT UNSIGNED NOT NULL DEFAULT 0,
  cancellations INT UNSIGNED NOT NULL DEFAULT 0,
  score DECIMAL(8,2) NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_tm_parent_score FOREIGN KEY (parent_request_id)
    REFERENCES tm_parent_requests(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tm_match_case_notes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  match_case_id BIGINT UNSIGNED NOT NULL,
  admin_user_id BIGINT UNSIGNED NOT NULL,
  contact_target ENUM('parent','tutor','both') NOT NULL DEFAULT 'both',
  note_type ENUM('note','call','whatsapp','email','trial','follow_up','status') NOT NULL DEFAULT 'note',
  note TEXT NOT NULL,
  next_action TEXT NULL,
  next_action_at DATETIME NULL,
  completed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_tm_notes_case (match_case_id, created_at),
  INDEX idx_tm_notes_followup (next_action_at, completed_at),
  CONSTRAINT fk_tm_note_case FOREIGN KEY (match_case_id)
    REFERENCES tm_match_cases(id) ON DELETE CASCADE,
  CONSTRAINT fk_tm_note_admin FOREIGN KEY (admin_user_id)
    REFERENCES tm_admin_users(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Deliberately not included here: live data import, password creation, file copying,
-- canonical subject dictionary, and API permissions. These need separate reviewed steps.
