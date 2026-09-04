<?php
require_once __DIR__ . '/../functions.php';
$account = currentAccount();
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= e(SERVER_NAME) ?></title>
<link rel="stylesheet" href="assets/style.css">
</head>
<body>
<header class="site-header">
  <a class="brand" href="index.php"><?= e(SERVER_NAME) ?></a>
  <nav>
    <a href="index.php">Home</a>
    <?php if ($account): ?>
      <a href="account.php">My Account</a>
      <a href="logout.php">Logout</a>
    <?php else: ?>
      <a href="login.php">Login</a>
      <a href="register.php">Register</a>
    <?php endif; ?>
  </nav>
</header>
<main class="container">
