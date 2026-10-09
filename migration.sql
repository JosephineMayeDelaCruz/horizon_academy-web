-- ═════════════════════════════════════════════════════════════════════════════
--  HORIZON ACADEMY — MIGRATION SCRIPT
--  Adds new roles, modules, and feature tables while preserving existing data.
--  Run this ONCE after backing up the existing database.
-- ═════════════════════════════════════════════════════════════════════════════

USE horizon_academy;

-- ── 1. Extend users.role to support new roles ─────────────────────────────
-- We drop the ENUM constraint and re-add it with new values.
ALTER TABLE users
    MODIFY COLUMN role ENUM('admin','faculty','student','registrar','cashier','department')
        NOT NULL DEFAULT 'student';

-- ── 2. Departments reference table ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS departments (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    code        VARCHAR(30)  NOT NULL UNIQUE,
    description TEXT         DEFAULT NULL,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── 3. Announcements ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS announcements (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    title      VARCHAR(200) NOT NULL,
    body       TEXT         NOT NULL,
    posted_by  INT          NOT NULL,
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ann_user FOREIGN KEY (posted_by) REFERENCES users(id) ON DELETE CASCADE
);

-- ── 4. Enrollment Queue ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS enrollment_queue (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    queue_number   VARCHAR(20)  NOT NULL,
    student_id     INT          NOT NULL,
    category       VARCHAR(60)  NOT NULL DEFAULT 'General Enrollment',
    status         ENUM('waiting','serving','completed','skipped') NOT NULL DEFAULT 'waiting',
    enrollment_period VARCHAR(30) NOT NULL DEFAULT '2025-2026-2',
    called_by      INT          DEFAULT NULL,
    called_at      DATETIME     DEFAULT NULL,
    served_at      DATETIME     DEFAULT NULL,
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_active_queue (student_id, enrollment_period, status),
    CONSTRAINT fk_eq_student FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    CONSTRAINT fk_eq_caller  FOREIGN KEY (called_by)  REFERENCES users(id)    ON DELETE SET NULL
);

-- ── 5. Clearance System ───────────────────────────────────────────────────
-- Department clearance requirements (configured per school year/sem)
CREATE TABLE IF NOT EXISTS clearance_requirements (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    department_id INT NOT NULL,
    requirement VARCHAR(200) NOT NULL,
    school_year VARCHAR(20)  NOT NULL DEFAULT '2025-2026',
    semester    TINYINT      NOT NULL DEFAULT 2,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cr_dept FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
);

-- Per-student clearance status per requirement
CREATE TABLE IF NOT EXISTS student_clearance (
    id                     INT AUTO_INCREMENT PRIMARY KEY,
    student_id             INT NOT NULL,
    requirement_id         INT NOT NULL,
    status                 ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    remarks                TEXT DEFAULT NULL,
    reviewed_by            INT DEFAULT NULL,
    reviewed_at            DATETIME DEFAULT NULL,
    created_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_student_req (student_id, requirement_id),
    CONSTRAINT fk_sc_student FOREIGN KEY (student_id)     REFERENCES students(id)              ON DELETE CASCADE,
    CONSTRAINT fk_sc_req     FOREIGN KEY (requirement_id) REFERENCES clearance_requirements(id) ON DELETE CASCADE,
    CONSTRAINT fk_sc_reviewer FOREIGN KEY (reviewed_by)   REFERENCES users(id)                 ON DELETE SET NULL
);

-- ── 6. Document Request System ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS document_types (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    fee         DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    description TEXT         DEFAULT NULL,
    is_active   TINYINT(1)   NOT NULL DEFAULT 1,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS document_requests (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    reference_no   VARCHAR(30)  NOT NULL UNIQUE,
    student_id     INT          NOT NULL,
    document_type_id INT        NOT NULL,
    purpose        TEXT         NOT NULL,
    copies         TINYINT      NOT NULL DEFAULT 1,
    status         ENUM('submitted','pending','processing','ready_for_pickup','completed','rejected') NOT NULL DEFAULT 'submitted',
    payment_status ENUM('unpaid','paid','waived') NOT NULL DEFAULT 'unpaid',
    fee_amount     DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    payment_ref    VARCHAR(80)  DEFAULT NULL,
    staff_remarks  TEXT         DEFAULT NULL,
    processed_by   INT          DEFAULT NULL,
    verified_by    INT          DEFAULT NULL,
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_dr_student  FOREIGN KEY (student_id)       REFERENCES students(id)      ON DELETE CASCADE,
    CONSTRAINT fk_dr_doctype  FOREIGN KEY (document_type_id) REFERENCES document_types(id) ON DELETE RESTRICT,
    CONSTRAINT fk_dr_processor FOREIGN KEY (processed_by)    REFERENCES users(id)          ON DELETE SET NULL,
    CONSTRAINT fk_dr_verifier  FOREIGN KEY (verified_by)     REFERENCES users(id)          ON DELETE SET NULL
);

-- Status history log for document requests
CREATE TABLE IF NOT EXISTS document_request_logs (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    request_id INT NOT NULL,
    old_status VARCHAR(30) DEFAULT NULL,
    new_status VARCHAR(30) NOT NULL,
    changed_by INT NOT NULL,
    remarks    TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_drl_request FOREIGN KEY (request_id) REFERENCES document_requests(id) ON DELETE CASCADE,
    CONSTRAINT fk_drl_user    FOREIGN KEY (changed_by)  REFERENCES users(id)             ON DELETE CASCADE
);

-- ── 7. Activity / Audit Log ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS activity_log (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT          NOT NULL,
    action      VARCHAR(200) NOT NULL,
    module      VARCHAR(60)  DEFAULT NULL,
    ip_address  VARCHAR(45)  DEFAULT NULL,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_al_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ── SEED: Department reference data ───────────────────────────────────────
INSERT IGNORE INTO departments (name, code, description) VALUES
  ('College of Computing Studies',   'CCS',      'Bachelor programs in Computing'),
  ('College of Engineering',         'CE',       'Bachelor programs in Engineering'),
  ('Library',                        'LIB',      'Library clearance'),
  ('Guidance Office',                'GUIDANCE', 'Student guidance clearance'),
  ('Finance / Cashier',              'FINANCE',  'Financial clearance'),
  ('Registrar',                      'REGISTRAR','Registrar office');

-- ── SEED: New staff users ─────────────────────────────────────────────────
-- Passwords stored as plaintext for development; run seed_passwords.php to hash them.
INSERT IGNORE INTO users (username, email, password, role, full_name, department) VALUES
  ('registrar', 'registrar@horizon.edu',  'reg123',  'registrar',  'Maria Santos',    'Registrar'),
  ('cashier',   'cashier@horizon.edu',    'cash123', 'cashier',    'Pedro Cruz',       'Finance / Cashier'),
  ('dept_ccs',  'dept.ccs@horizon.edu',   'dept123', 'department', 'CCS Department Head', 'College of Computing Studies');

-- ── SEED: Clearance requirements ─────────────────────────────────────────
INSERT IGNORE INTO clearance_requirements (department_id, requirement, school_year, semester)
SELECT d.id, req.requirement, '2025-2026', 2
FROM departments d
JOIN (
  SELECT 'CCS'      AS code, 'Submit Laboratory Forms'          AS requirement UNION ALL
  SELECT 'CCS',              'Return Borrowed Equipment'         UNION ALL
  SELECT 'LIB',              'Return All Borrowed Library Books' UNION ALL
  SELECT 'LIB',              'Settle Library Fines'              UNION ALL
  SELECT 'GUIDANCE',         'Guidance Clearance Form'           UNION ALL
  SELECT 'FINANCE',          'Settle All Financial Obligations'  UNION ALL
  SELECT 'FINANCE',          'Return School ID (if graduating)'  UNION ALL
  SELECT 'REGISTRAR',        'Submit Enrollment Form'            UNION ALL
  SELECT 'REGISTRAR',        'Update Personal Information'
) AS req ON d.code = req.code;

-- ── SEED: Document types ──────────────────────────────────────────────────
INSERT IGNORE INTO document_types (name, fee, description) VALUES
  ('Certificate of Enrollment',    50.00,  'Official certificate confirming student enrollment'),
  ('Transcript of Records (TOR)',  150.00, 'Official academic transcript'),
  ('Certificate of Grades',        50.00,  'Certified copy of grades per semester'),
  ('Good Moral Certificate',       50.00,  'Certificate of good moral character'),
  ('Certificate of Graduation',   100.00,  'Official graduation certificate'),
  ('Honorable Dismissal',         100.00,  'Honorable dismissal form'),
  ('Authentication',               30.00,  'Authentication of school documents');
