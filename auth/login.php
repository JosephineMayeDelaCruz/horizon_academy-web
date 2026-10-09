<?php
/**
 * ═══════════════════════════════════════════════════════════
 * LOGIN PROCESSOR — auth/login.php
 * ═══════════════════════════════════════════════════════════
 * Handles form submission: validates credentials and sets session
 * Uses INNER JOIN to fetch user + role-specific data
 */

require_once __DIR__ . '/../config/auth.php';

function passwordMatches(string $input, string $stored): bool {
    // Try both password_verify (for hashed) and direct comparison (for plaintext).
    return password_verify($input, $stored) || hash_equals($stored, $input);
}

// Only process login requests from forms, redirect other requests to home page.
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: ' . url('index.php'));
    exit;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// VALIDATE INPUT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$role     = trim($_POST['role']     ?? '');
$username = trim($_POST['username'] ?? '');
$password = trim($_POST['password'] ?? '');

$validRoles = ['admin', 'faculty', 'student', 'registrar', 'cashier', 'department'];
if (!in_array($role, $validRoles, true) || !$username || !$password) {
    redirectWith('/index.php', 'Please fill in all fields.', 'error');
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FETCH USER — INNER JOIN to ensure role matches
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Connect to database and prepare a query to find user by username and role.
$pdo  = getDB();
$stmt = $pdo->prepare(
    "SELECT 
        u.id,
        u.username,
        u.email,
        u.password,
        u.role,
        u.full_name,
        u.department
     FROM users u
     WHERE u.username = ? AND u.role = ?
     LIMIT 1"
);
// Execute query with the username and role from the login form.
$stmt->execute([$username, $role]);
$user = $stmt->fetch();

// If user not found or password is wrong, reject the login attempt.
if (!$user || !passwordMatches($password, $user['password'])) {
    redirectWith('index.php', 'Invalid username or password.', 'error');
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BUILD SESSION DATA
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Store the user ID and role in session for quick access throughout the application.
$_SESSION['user_id'] = $user['id'];
$_SESSION['role']    = $user['role'];

// Create an array with user information to store in the session.
$userData = [
    'id'         => $user['id'],
    'username'   => $user['username'],
    'email'      => $user['email'],
    'role'       => $user['role'],
    'full_name'  => $user['full_name'],
    'department' => $user['department'],
];

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FETCH STUDENT PROFILE (if student role)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// If user is a student, load their student profile from the students table.
if ($role === 'student') {
    $stmt = $pdo->prepare(
        "SELECT id, student_number, program, section, year_level
         FROM students
         WHERE user_id = ?
         LIMIT 1"
    );
    $stmt->execute([$user['id']]);
    $student = $stmt->fetch() ?: [];
    
    // Add student-specific data to the session so it's available throughout their session.
    $userData = array_merge($userData, $student);
    $userData['student_db_id'] = $student['id'] ?? 0;
}

// Store all collected user information in the session for later use.
$_SESSION['user'] = $userData;

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// REDIRECT TO DASHBOARD
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Create a map of dashboard URLs for each user role.
$dashboards = [
    'admin'      => url('admin/dashboard.php'),
    'faculty'    => url('faculty/dashboard.php'),
    'student'    => url('student/dashboard.php'),
    'registrar'  => url('registrar/dashboard.php'),
    'cashier'    => url('cashier/dashboard.php'),
    'department' => url('department/dashboard.php'),
];

// Send the user to their role-specific dashboard after successful login.
header('Location: ' . $dashboards[$role]);
exit;
