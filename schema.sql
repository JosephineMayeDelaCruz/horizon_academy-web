-- ═════════════════════════════════════════════════════════════════════════════
--  HORIZON ACADEMY — STUDENT ATTENDANCE & GRADING SYSTEM
--  Database Schema: 5 Normalized Tables (3NF Design)
-- ═════════════════════════════════════════════════════════════════════════════
--
-- NORMALIZATION PRINCIPLES APPLIED:
-- 1NF: Atomic values only (no arrays, repeating groups)
-- 2NF: All non-key attributes depend on ENTIRE primary key (no partial deps)
-- 3NF: No non-key attribute depends on another non-key (no transitive deps)
--
-- RELATIONSHIPS:
--   users → (1-to-Many) → students (One admin/faculty per row, one student per user)
--   users → (1-to-Many) → courses (Faculty can teach multiple courses)
--   students → (Many-to-Many) → courses [via attendance & grades]
--   attendance & grades maintain referential integrity via FOREIGN KEYS
--
-- GROUP 4 | CCS110 Information Management 1
-- ═════════════════════════════════════════════════════════════════════════════

CREATE DATABASE IF NOT EXISTS horizon_academy
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE horizon_academy;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS grades;
DROP TABLE IF EXISTS attendance;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- ── TABLE 1: users ─────────────────────────────────────────
-- Stores all system users: admin, faculty, and students.
-- Authentication and role-based access control are handled here.
CREATE TABLE users (
    id         INT          AUTO_INCREMENT PRIMARY KEY,
    username   VARCHAR(100) NOT NULL UNIQUE,
    email      VARCHAR(150) NOT NULL UNIQUE,
    password   VARCHAR(255) NOT NULL,
    role       ENUM('admin','faculty','student') NOT NULL,
    full_name  VARCHAR(150) NOT NULL,
    department VARCHAR(100) DEFAULT NULL,        -- faculty: dept, admin: NULL
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_users_role    CHECK (role IN ('admin','faculty','student')),
    CONSTRAINT chk_users_email   CHECK (email LIKE '%@%.%')
);

-- ── TABLE 2: students ──────────────────────────────────────
-- Stores student-specific profile data.
-- One-to-One with users (user_id is unique).
CREATE TABLE students (
    id             INT         AUTO_INCREMENT PRIMARY KEY,
    user_id        INT         NOT NULL UNIQUE,
    student_number VARCHAR(20) NOT NULL UNIQUE,
    program        VARCHAR(50) NOT NULL DEFAULT 'BSCS',
    section        VARCHAR(20) NOT NULL DEFAULT '1-A',
    year_level     TINYINT     NOT NULL DEFAULT 1,
    CONSTRAINT fk_students_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_students_year CHECK (year_level BETWEEN 1 AND 4),
    CONSTRAINT chk_students_prog CHECK (program IN ('BSCS','BSIT','BSIS','BSCE','BSEE'))
);

-- ── TABLE 3: courses ───────────────────────────────────────
-- Stores subject/course definitions assigned to a faculty member.
-- One faculty teaches many courses (Many-to-One with users).
CREATE TABLE courses (
    id          INT          AUTO_INCREMENT PRIMARY KEY,
    course_code VARCHAR(20)  NOT NULL UNIQUE,
    title       VARCHAR(150) NOT NULL,
    section     VARCHAR(20)  NOT NULL,
    schedule    VARCHAR(80)  NOT NULL DEFAULT 'TBA',
    teacher_id  INT          NOT NULL,
    max_lessons INT          NOT NULL DEFAULT 54,
    school_year VARCHAR(20)  NOT NULL DEFAULT '2025-2026',
    semester    TINYINT      NOT NULL DEFAULT 2,
    CONSTRAINT fk_courses_teacher FOREIGN KEY (teacher_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_courses_sem      CHECK (semester IN (1, 2)),
    CONSTRAINT chk_courses_maxless  CHECK (max_lessons > 0)
);

-- ── TABLE 4: attendance ────────────────────────────────────
-- Records per-student, per-course, per-date attendance status.
-- Many-to-Many bridge between students and courses with date+status payload.
-- FK to students.id and courses.id ensures referential integrity.
CREATE TABLE attendance (
    id         INT  AUTO_INCREMENT PRIMARY KEY,
    student_id INT  NOT NULL,
    course_id  INT  NOT NULL,
    date       DATE NOT NULL,
    status     ENUM('present','absent','late') NOT NULL DEFAULT 'present',
    recorded_by INT NOT NULL,
    UNIQUE KEY uq_attend (student_id, course_id, date),
    CONSTRAINT fk_attend_student FOREIGN KEY (student_id)
        REFERENCES students(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_attend_course FOREIGN KEY (course_id)
        REFERENCES courses(id)  ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_attend_recorder FOREIGN KEY (recorded_by)
        REFERENCES users(id)    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_attend_status CHECK (status IN ('present','absent','late'))
);

-- ── TABLE 5: grades ────────────────────────────────────────
-- Stores component grades and computed final grade per student per course.
-- Components must be 0–100; final_grade is a STORED computed column.
-- Weighted formula: Prelim 30% + Midterm 30% + Finals 40%.
CREATE TABLE grades (
    id            INT            AUTO_INCREMENT PRIMARY KEY,
    student_id    INT            NOT NULL,
    course_id     INT            NOT NULL,
    prelim        DECIMAL(5,2)   NOT NULL DEFAULT 0.00,
    midterm       DECIMAL(5,2)   NOT NULL DEFAULT 0.00,
    finals        DECIMAL(5,2)   NOT NULL DEFAULT 0.00,
    final_grade   DECIMAL(5,2)   GENERATED ALWAYS AS (
                      ROUND((prelim * 0.30) + (midterm * 0.30) + (finals * 0.40), 2)
                  ) STORED,
    remarks       VARCHAR(20)    GENERATED ALWAYS AS (
                      CASE
                          WHEN ROUND((prelim * 0.30)+(midterm * 0.30)+(finals * 0.40),2) >= 75
                          THEN 'PASSED' ELSE 'FAILED'
                      END
                  ) STORED,
    submitted_by  INT            NOT NULL,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_grade (student_id, course_id),
    CONSTRAINT fk_grades_student FOREIGN KEY (student_id)
        REFERENCES students(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_grades_course  FOREIGN KEY (course_id)
        REFERENCES courses(id)  ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_grades_submitter FOREIGN KEY (submitted_by)
        REFERENCES users(id)    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_grades_prelim   CHECK (prelim   BETWEEN 0 AND 100),
    CONSTRAINT chk_grades_midterm  CHECK (midterm  BETWEEN 0 AND 100),
    CONSTRAINT chk_grades_finals   CHECK (finals   BETWEEN 0 AND 100)
);

-- ============================================================
--  SEED DATA — Minimum 5 records per main table
-- ============================================================

-- NOTE: All passwords are stored in plaintext for direct comparison.
-- Run seed_passwords.php AFTER importing to reset passwords if needed.

-- Users (1 admin, 3 faculty, 6 students)
INSERT INTO users (username, email, password, role, full_name, department) VALUES
  ('admin',     'admin@horizon.edu',             'admin123', 'admin',   'System Administrator', NULL),
  ('rfernandez','rfernandez@horizon.edu',         'fac123', 'faculty', 'Raissa Fernandez',     'College of Computing Studies'),
  ('jmendoza',  'jmendoza@horizon.edu',           'fac123', 'faculty', 'Jose Mendoza',         'College of Computing Studies'),
  ('asantos',   'asantos@horizon.edu',            'fac123', 'faculty', 'Ana Santos',           'College of Computing Studies'),
  ('mreyes',    'mreyes@horizon.edu',             'fac123', 'faculty', 'Mario Reyes',          'College of Engineering'),
  ('2403938',   'micahdelacruz@studenthorizon.edu','stu123','student', 'Micah Dela Cruz',      NULL),
  ('2403939',   'juana.reyes@studenthorizon.edu', 'stu123', 'student', 'Juana Reyes',          NULL),
  ('2403940',   'carlos.tan@studenthorizon.edu',  'stu123', 'student', 'Carlos Tan',           NULL),
  ('2403941',   'sophia.lim@studenthorizon.edu',  'stu123', 'student', 'Sophia Lim',           NULL),
  ('2403942',   'alden.garcia@studenthorizon.edu','stu123', 'student', 'Alden Garcia',         NULL),
  ('2403943',   'grace.ocon@studenthorizon.edu',  'stu123', 'student', 'Grace Ocon',           NULL);

-- Students (linked to user records above; users 6-11 are students)
INSERT INTO students (user_id, student_number, program, section, year_level)
SELECT id, username, 'BSCS', '2-A', 2 FROM users WHERE role='student';

-- Courses (teacher_id references faculty users 2-5)
INSERT INTO courses (course_code, title, section, schedule, teacher_id, max_lessons, school_year, semester)
VALUES
  ('CCS110', 'Information Management 1',      '2-A', 'MWF 7:00-8:30 AM',  2, 54, '2025-2026', 2),
  ('CCS111', 'Object-Oriented Programming',   '2-A', 'TTh 8:30-10:00 AM', 3, 54, '2025-2026', 2),
  ('CCS112', 'Data Structures and Algorithms','2-A', 'MWF 10:00-11:30 AM',4, 54, '2025-2026', 2),
  ('CCS113', 'Web Systems and Technologies',  '2-A', 'TTh 1:00-2:30 PM',  2, 54, '2025-2026', 2),
  ('CCS114', 'Computer Networks',             '2-A', 'MWF 1:00-2:30 PM',  5, 54, '2025-2026', 2);

-- Attendance records (student_id 1 = Micah, recorded by faculty user_id 2)
INSERT INTO attendance (student_id, course_id, date, status, recorded_by) VALUES
  (1, 1, '2026-01-05', 'present', 2),
  (1, 1, '2026-01-07', 'present', 2),
  (1, 1, '2026-01-09', 'late',    2),
  (1, 1, '2026-01-12', 'absent',  2),
  (1, 1, '2026-01-14', 'present', 2),
  (2, 1, '2026-01-05', 'present', 2),
  (2, 1, '2026-01-07', 'absent',  2),
  (2, 1, '2026-01-09', 'present', 2),
  (2, 1, '2026-01-12', 'present', 2),
  (2, 1, '2026-01-14', 'present', 2),
  (3, 1, '2026-01-05', 'late',    2),
  (3, 1, '2026-01-07', 'present', 2),
  (3, 1, '2026-01-09', 'present', 2),
  (3, 1, '2026-01-12', 'absent',  2),
  (3, 1, '2026-01-14', 'absent',  2),
  (4, 1, '2026-01-05', 'present', 2),
  (4, 1, '2026-01-07', 'present', 2),
  (4, 1, '2026-01-09', 'present', 2),
  (4, 1, '2026-01-12', 'present', 2),
  (4, 1, '2026-01-14', 'present', 2),
  (5, 1, '2026-01-05', 'absent',  2),
  (5, 1, '2026-01-07', 'absent',  2),
  (5, 1, '2026-01-09', 'present', 2),
  (5, 1, '2026-01-12', 'present', 2),
  (5, 1, '2026-01-14', 'late',    2),
  (6, 1, '2026-01-05', 'present', 2),
  (6, 1, '2026-01-07', 'present', 2),
  (6, 1, '2026-01-09', 'present', 2),
  (6, 1, '2026-01-12', 'late',    2),
  (6, 1, '2026-01-14', 'present', 2);

-- Grades (submitted by faculty user_id 2; all 6 students, course 1)
INSERT INTO grades (student_id, course_id, prelim, midterm, finals, submitted_by) VALUES
  (1, 1, 88.00, 85.00, 90.00, 2),
  (2, 1, 76.00, 78.00, 82.00, 2),
  (3, 1, 65.00, 70.00, 68.00, 2),
  (4, 1, 95.00, 92.00, 94.00, 2),
  (5, 1, 55.00, 60.00, 58.00, 2),
  (6, 1, 80.00, 83.00, 87.00, 2);

-- ============================================================
--  SAMPLE SQL QUERY DEMONSTRATIONS (for documentation)
-- ============================================================

-- SELECT with JOIN: Get student grades with course and faculty info
-- SELECT u.full_name AS student, c.course_code, c.title,
--        g.prelim, g.midterm, g.finals, g.final_grade, g.remarks
-- FROM grades g
-- JOIN students s   ON s.id = g.student_id
-- JOIN users u      ON u.id = s.user_id
-- JOIN courses c    ON c.id = g.course_id
-- WHERE g.remarks = 'PASSED'
-- ORDER BY g.final_grade DESC;

-- SELECT with GROUP BY: Attendance summary per student per course
-- SELECT u.full_name, c.course_code,
--        SUM(CASE WHEN a.status='present' THEN 1 ELSE 0 END) AS present_count,
--        SUM(CASE WHEN a.status='absent'  THEN 1 ELSE 0 END) AS absent_count,
--        COUNT(*) AS total
-- FROM attendance a
-- JOIN students s ON s.id = a.student_id
-- JOIN users u    ON u.id = s.user_id
-- JOIN courses c  ON c.id = a.course_id
-- GROUP BY s.id, a.course_id
-- ORDER BY u.full_name;

-- UPDATE: Correct a grade entry
-- UPDATE grades SET midterm = 82.00 WHERE student_id = 1 AND course_id = 1;

-- DELETE: Remove an erroneous attendance record
-- DELETE FROM attendance WHERE student_id = 1 AND course_id = 1 AND date = '2026-01-09';
