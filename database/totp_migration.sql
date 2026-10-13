-- ═════════════════════════════════════════════════════════════════════════════
--  HORIZON ACADEMY — TOTP MIGRATION
--  Adds TOTP secret storage to the students table for physical presence
--  verification in the enrollment queue.
--  Run ONCE against a database that already has migration.sql applied.
-- ═════════════════════════════════════════════════════════════════════════════

USE horizon_academy;

ALTER TABLE students
    ADD COLUMN IF NOT EXISTS totp_secret VARCHAR(32) DEFAULT NULL
        COMMENT 'Base32-encoded TOTP shared secret; NULL until student enrolls in TOTP verification';
