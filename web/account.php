<?php
require_once __DIR__ . '/functions.php';

$account = requireLogin();

$emailError = null;
$emailSuccess = false;
$passwordError = null;
$passwordSuccess = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && checkCsrf()) {
    $stmt = db()->prepare('SELECT `password` FROM `accounts` WHERE `id` = ?');
    $stmt->execute([$account['id']]);
    $storedHash = $stmt->fetchColumn();

    if (($_POST['form'] ?? '') === 'email') {
        $currentPassword = (string) ($_POST['current_password'] ?? '');
        $email = trim($_POST['email'] ?? '');

        if (!passwordMatches($currentPassword, $storedHash)) {
            $emailError = 'Current password is incorrect.';
        } elseif ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $emailError = 'Email address is not valid.';
        } else {
            $stmt = db()->prepare('UPDATE `accounts` SET `email` = ? WHERE `id` = ?');
            $stmt->execute([$email, $account['id']]);
            $account['email'] = $email;
            $emailSuccess = true;
        }
    } elseif (($_POST['form'] ?? '') === 'password') {
        $currentPassword = (string) ($_POST['current_password'] ?? '');
        $newPassword = (string) ($_POST['new_password'] ?? '');
        $confirmPassword = (string) ($_POST['confirm_password'] ?? '');

        if (!passwordMatches($currentPassword, $storedHash)) {
            $passwordError = 'Current password is incorrect.';
        } elseif ($newPassword !== $confirmPassword) {
            $passwordError = 'New passwords do not match.';
        } elseif ($err = validatePassword($newPassword)) {
            $passwordError = $err;
        } else {
            $stmt = db()->prepare('UPDATE `accounts` SET `password` = ? WHERE `id` = ?');
            $stmt->execute([hashPassword($newPassword), $account['id']]);
            $passwordSuccess = true;
        }
    }
}

$characters = db()->prepare(
    'SELECT `name`, `level`, `vocation`, `lastlogin` FROM `players` WHERE `account_id` = ? AND `deletion` = 0 ORDER BY `name` ASC'
);
$characters->execute([$account['id']]);
$characters = $characters->fetchAll();

require __DIR__ . '/includes/header.php';
?>

<div class="panel">
  <h1>Account: <?= e($account['name']) ?></h1>
  <h2>Characters</h2>
  <?php if ($characters): ?>
  <table>
    <thead><tr><th>Name</th><th>Level</th><th>Vocation</th><th>Last login</th></tr></thead>
    <tbody>
      <?php foreach ($characters as $c): ?>
      <tr>
        <td><?= e($c['name']) ?></td>
        <td><?= (int) $c['level'] ?></td>
        <td><?= e(vocationName((int) $c['vocation'])) ?></td>
        <td><?= $c['lastlogin'] ? e(date('Y-m-d H:i', (int) $c['lastlogin'])) : 'Never' ?></td>
      </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
  <?php else: ?>
    <p>No characters yet.</p>
  <?php endif; ?>
  <p><a href="create_character.php">Create a new character</a></p>
</div>

<div class="panel">
  <h2>Change email</h2>
  <?php if ($emailError): ?><div class="alert alert-error"><?= e($emailError) ?></div><?php endif; ?>
  <?php if ($emailSuccess): ?><div class="alert alert-success">Email updated.</div><?php endif; ?>
  <form method="post" novalidate>
    <input type="hidden" name="csrf_token" value="<?= e(csrfToken()) ?>">
    <input type="hidden" name="form" value="email">
    <div>
      <label for="email">Email</label>
      <input type="email" id="email" name="email" value="<?= e($account['email'] ?? '') ?>">
    </div>
    <div>
      <label for="current_password_email">Current password</label>
      <input type="password" id="current_password_email" name="current_password" required>
    </div>
    <button type="submit">Update email</button>
  </form>
</div>

<div class="panel">
  <h2>Change password</h2>
  <?php if ($passwordError): ?><div class="alert alert-error"><?= e($passwordError) ?></div><?php endif; ?>
  <?php if ($passwordSuccess): ?><div class="alert alert-success">Password updated.</div><?php endif; ?>
  <form method="post" novalidate>
    <input type="hidden" name="csrf_token" value="<?= e(csrfToken()) ?>">
    <input type="hidden" name="form" value="password">
    <div>
      <label for="current_password">Current password</label>
      <input type="password" id="current_password" name="current_password" required>
    </div>
    <div>
      <label for="new_password">New password</label>
      <input type="password" id="new_password" name="new_password"
             minlength="<?= PASSWORD_MIN_LENGTH ?>" maxlength="<?= PASSWORD_MAX_LENGTH ?>" required>
    </div>
    <div>
      <label for="confirm_password">Confirm new password</label>
      <input type="password" id="confirm_password" name="confirm_password" required>
    </div>
    <button type="submit">Update password</button>
  </form>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>
