<?php
require_once __DIR__ . '/functions.php';

$account = requireLogin();

$error = null;
$success = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!checkCsrf()) {
        $error = 'Your session expired, please try again.';
    } else {
        $name = trim($_POST['name'] ?? '');
        $sexInput = $_POST['sex'] ?? '';
        $vocationId = (int) ($_POST['vocation'] ?? 0);

        $sex = $sexInput === 'female' ? SEX_FEMALE : ($sexInput === 'male' ? SEX_MALE : null);

        $error = validateCharacterName($name);
        if (!$error && $sex === null) {
            $error = 'Please choose a sex.';
        }
        if (!$error && !isset(CREATABLE_VOCATIONS[$vocationId])) {
            $error = 'Please choose a vocation.';
        }
        if (!$error && characterExists($name)) {
            $error = 'A character with that name already exists.';
        }

        if (!$error) {
            createCharacter($account['id'], $name, $sex, $vocationId, $_SERVER['REMOTE_ADDR']);
            $success = true;
        }
    }
}

require __DIR__ . '/includes/header.php';
?>

<div class="panel">
  <h1>Create a character</h1>

  <?php if ($success): ?>
    <div class="alert alert-success">
      Character created! <a href="account.php">Back to My Account</a> to see it, then log in with
      OTClient to play.
    </div>
  <?php else: ?>
    <?php if ($error): ?><div class="alert alert-error"><?= e($error) ?></div><?php endif; ?>
    <form method="post" novalidate>
      <input type="hidden" name="csrf_token" value="<?= e(csrfToken()) ?>">
      <div>
        <label for="name">Character name</label>
        <input type="text" id="name" name="name" value="<?= e($_POST['name'] ?? '') ?>"
               minlength="<?= CHARACTER_NAME_MIN_LENGTH ?>" maxlength="<?= CHARACTER_NAME_MAX_LENGTH ?>" required>
      </div>
      <div>
        <label for="sex">Sex</label>
        <select id="sex" name="sex" required>
          <option value="">Choose...</option>
          <option value="male" <?= ($_POST['sex'] ?? '') === 'male' ? 'selected' : '' ?>>Male</option>
          <option value="female" <?= ($_POST['sex'] ?? '') === 'female' ? 'selected' : '' ?>>Female</option>
        </select>
      </div>
      <div>
        <label for="vocation">Vocation</label>
        <select id="vocation" name="vocation" required>
          <option value="">Choose...</option>
          <?php foreach (CREATABLE_VOCATIONS as $id => $label): ?>
            <option value="<?= $id ?>" <?= (int) ($_POST['vocation'] ?? 0) === $id ? 'selected' : '' ?>><?= e($label) ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <button type="submit">Create character</button>
    </form>
    <p>Name: letters and spaces only, each word capitalized, <?= CHARACTER_NAME_MIN_LENGTH ?>-<?= CHARACTER_NAME_MAX_LENGTH ?>
    characters, up to <?= CHARACTER_NAME_MAX_WORDS ?> words (e.g. "John Doe").</p>
  <?php endif; ?>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>
