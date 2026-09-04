<?php
require_once __DIR__ . '/functions.php';

const ACCOUNT_MANAGER_ACCOUNT_ID = 1;

if (currentAccount()) {
    header('Location: account.php');
    exit;
}

$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!checkCsrf()) {
        $error = 'Your session expired, please try again.';
    } else {
        $accountName = trim($_POST['account_name'] ?? '');
        $password = (string) ($_POST['password'] ?? '');

        $stmt = db()->prepare('SELECT `id`, `password` FROM `accounts` WHERE `name` = ?');
        $stmt->execute([$accountName]);
        $row = $stmt->fetch();

        if (!$row || (int) $row['id'] === ACCOUNT_MANAGER_ACCOUNT_ID || !passwordMatches($password, $row['password'])) {
            usleep(300000); // basic throttle against scripted brute forcing
            $error = 'Invalid account name or password.';
        } else {
            session_regenerate_id(true);
            $_SESSION['account_id'] = (int) $row['id'];
            header('Location: account.php');
            exit;
        }
    }
}

require __DIR__ . '/includes/header.php';
?>

<div class="panel">
  <h1>Login</h1>
  <?php if ($error): ?><div class="alert alert-error"><?= e($error) ?></div><?php endif; ?>
  <form method="post" novalidate>
    <input type="hidden" name="csrf_token" value="<?= e(csrfToken()) ?>">
    <div>
      <label for="account_name">Account name</label>
      <input type="text" id="account_name" name="account_name" value="<?= e($_POST['account_name'] ?? '') ?>" required>
    </div>
    <div>
      <label for="password">Password</label>
      <input type="password" id="password" name="password" required>
    </div>
    <button type="submit">Log in</button>
  </form>
  <p>No account yet? <a href="register.php">Register</a>.</p>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>
