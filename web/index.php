<?php
require_once __DIR__ . '/functions.php';

$playerCount = null;
$players = [];
$dbError = false;
try {
    $playerCount = onlinePlayerCount();
    $players = onlinePlayers();
} catch (Throwable $e) {
    $dbError = true;
}

require __DIR__ . '/includes/header.php';
?>

<div class="panel">
  <h1><?= e(SERVER_NAME) ?></h1>
  <p>A Tibia 8.60-protocol server. Connect with OTClient Redemption to
  <strong><?= e(SERVER_HOST) ?>:<?= e((string) SERVER_GAME_PORT) ?></strong>.</p>
  <div class="stat-row">
    <div class="stat">
      <div class="label">Status</div>
      <div class="value <?= $dbError ? 'status-offline' : 'status-online' ?>">
        <?= $dbError ? 'Unknown' : 'Online' ?>
      </div>
    </div>
    <div class="stat">
      <div class="label">Players online</div>
      <div class="value"><?= $dbError ? '?' : (int) $playerCount ?></div>
    </div>
    <div class="stat">
      <div class="label">World type</div>
      <div class="value"><?= e(SERVER_WORLD_TYPE) ?></div>
    </div>
  </div>
</div>

<?php if (!$dbError && $players): ?>
<div class="panel">
  <h2>Who's online</h2>
  <table>
    <thead><tr><th>Name</th><th>Level</th><th>Vocation</th></tr></thead>
    <tbody>
      <?php foreach ($players as $p): ?>
      <tr>
        <td><?= e($p['name']) ?></td>
        <td><?= (int) $p['level'] ?></td>
        <td><?= e(vocationName((int) $p['vocation'])) ?></td>
      </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>
<?php endif; ?>

<div class="panel">
  <h2>Get started</h2>
  <p>New here? <a href="register.php">Create an account</a>, then log in to
  <a href="account.php">create your first character</a>.</p>
  <p>Already have an account? <a href="login.php">Log in</a> to manage it.</p>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>
