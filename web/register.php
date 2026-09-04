<?php
require_once __DIR__ . '/functions.php';

if (currentAccount()) {
    header('Location: account.php');
    exit;
}

$error = null;
$success = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!checkCsrf()) {
        $error = 'Your session expired, please try again.';
    } else {
        $accountName = trim($_POST['account_name'] ?? '');
        $password = (string) ($_POST['password'] ?? '');
        $confirmPassword = (string) ($_POST['confirm_password'] ?? '');
        $email = trim($_POST['email'] ?? '');

        $error = validateAccountName($accountName) ?? validatePassword($password);
        if (!$error && $password !== $confirmPassword) {
            $error = 'Passwords do not match.';
        }
        if (!$error && $email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $error = 'Email address is not valid.';
        }
        if (!$error && accountExists($accountName)) {
            $error = 'An account with that name already exists.';
        }

        if (!$error) {
            $stmt = db()->prepare(
                'INSERT INTO `accounts` (`name`, `password`, `email`, `creation`) VALUES (?, ?, ?, ?)'
            );
            $stmt->execute([$accountName, hashPassword($password), $email, time()]);
            $success = true;
        }
    }
}

require __DIR__ . '/includes/header.php';
?>

<div class="panel">
  <h1>Create an account</h1>

  <?php if ($success): ?>
    <div class="alert alert-success">
      Account created! <a href="login.php">Log in</a> now to create your first character.
    </div>
  <?php else: ?>
    <?php if ($error): ?><div class="alert alert-error"><?= e($error) ?></div><?php endif; ?>
    <form method="post" novalidate>
      <input type="hidden" name="csrf_token" value="<?= e(csrfToken()) ?>">
      <div>
        <label for="account_name">Account name</label>
        <input type="text" id="account_name" name="account_name"
               value="<?= e($_POST['account_name'] ?? '') ?>"
               minlength="<?= ACCOUNT_NAME_MIN_LENGTH ?>" maxlength="<?= ACCOUNT_NAME_MAX_LENGTH ?>" required>
      </div>
      <div>
        <label for="password">Password</label>
        <input type="password" id="password" name="password"
               minlength="<?= PASSWORD_MIN_LENGTH ?>" maxlength="<?= PASSWORD_MAX_LENGTH ?>" required>
      </div>
      <div>
        <label for="confirm_password">Confirm password</label>
        <input type="password" id="confirm_password" name="confirm_password" required>
      </div>
      <div>
        <label for="email">Email (optional)</label>
        <input type="email" id="email" name="email" value="<?= e($_POST['email'] ?? '') ?>">
      </div>
      <button type="submit">Create account</button>
    </form>
    <p>Account name: letters only, <?= ACCOUNT_NAME_MIN_LENGTH ?>-<?= ACCOUNT_NAME_MAX_LENGTH ?> characters.
    Password: <?= PASSWORD_MIN_LENGTH ?>-<?= PASSWORD_MAX_LENGTH ?> characters, at least one number and one capital letter.</p>
  <?php endif; ?>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>
