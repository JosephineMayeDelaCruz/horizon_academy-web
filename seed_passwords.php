<?php
/**
 * ═══════════════════════════════════════════════════════════
 * SEED PASSWORDS — Run once to hash all plaintext passwords
 * ═══════════════════════════════════════════════════════════
 * Access: http://localhost/horizon_academy/seed_passwords.php
 * DELETE or restrict this file after running.
 */

require_once __DIR__ . '/config/db.php';

$pdo = getDB();

// Only hash passwords that are not already hashed (not starting with $2y$)
$users = $pdo->query("SELECT id, password FROM users")->fetchAll();
$count = 0;

foreach ($users as $u) {
    // Skip already-hashed passwords
    if (str_starts_with($u['password'], '$2y$')) continue;

    $hashed = password_hash($u['password'], PASSWORD_DEFAULT);
    $pdo->prepare("UPDATE users SET password=? WHERE id=?")->execute([$hashed, $u['id']]);
    $count++;
}

echo '<!DOCTYPE html><html><head><meta charset="UTF-8">
<title>Seed Passwords</title>
<style>body{font-family:sans-serif;padding:40px;background:#F5F0E8;}
.box{background:#fff;padding:24px;border-radius:12px;max-width:400px;box-shadow:0 4px 16px rgba(0,0,0,.1);}
.ok{color:#4A7C59;font-weight:700;}</style></head><body>
<div class="box">
<h2>Password Seed Complete</h2>
<p class="ok">✅ ' . $count . ' password(s) hashed successfully.</p>
<p style="color:#9E8E80;font-size:.88rem;margin-top:12px;">You can now log in with the original passwords. Delete this file after use.</p>
<p style="margin-top:16px;"><a href="index.php" style="color:#806B52;">→ Go to Login</a></p>
</div></body></html>';
