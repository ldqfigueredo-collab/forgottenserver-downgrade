<?php
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/db.php';

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}

// TFS stores accounts.password as HEX(SHA1(password)) — a 40-char hex string the
// server decodes with UNHEX() and compares byte-for-byte against a fresh SHA1 of the
// submitted password (src/iologindata.cpp). PHP's sha1() already returns that same
// lowercase hex form, so no extra encoding step is needed on this side.
function hashPassword(string $password): string
{
    return sha1($password);
}

function passwordMatches(string $password, string $storedHashHex): bool
{
    // Accounts created in-game hex-encode via MySQL's HEX(), which is uppercase;
    // accounts created here use PHP's lowercase sha1(). Compare case-insensitively.
    return hash_equals(strtolower($storedHashHex), strtolower(hashPassword($password)));
}

// Mirrors validateAccountName() in data/scripts/eventcallbacks/account_manager.lua.
function validateAccountName(string $name): ?string
{
    $length = strlen($name);
    if ($length < ACCOUNT_NAME_MIN_LENGTH) {
        return 'Account name is too short.';
    }
    if ($length > ACCOUNT_NAME_MAX_LENGTH) {
        return 'Account name is too long.';
    }
    if (preg_match('/\d/', $name)) {
        return 'Account name may not contain numbers.';
    }
    if (!preg_match('/^\w+$/', $name)) {
        return 'Account name may not contain special characters.';
    }
    return null;
}

// Mirrors validatePassword() in data/scripts/eventcallbacks/account_manager.lua.
function validatePassword(string $password): ?string
{
    $length = strlen($password);
    if ($length < PASSWORD_MIN_LENGTH) {
        return 'Password is too short.';
    }
    if ($length > PASSWORD_MAX_LENGTH) {
        return 'Password is too long.';
    }
    if (!preg_match('/\d/', $password)) {
        return 'Password must contain a number.';
    }
    if (!preg_match('/[A-Z]/', $password)) {
        return 'Password must contain a capital letter.';
    }
    return null;
}

function accountExists(string $name): bool
{
    $stmt = db()->prepare('SELECT 1 FROM `accounts` WHERE `name` = ? LIMIT 1');
    $stmt->execute([$name]);
    return (bool) $stmt->fetchColumn();
}

function characterExists(string $name): bool
{
    $stmt = db()->prepare('SELECT 1 FROM `players` WHERE `name` = ? LIMIT 1');
    $stmt->execute([$name]);
    return (bool) $stmt->fetchColumn();
}

// Mirrors string.titleCase() in data/global.lua: uppercase the first letter of
// each word, lowercase the rest.
function titleCase(string $str): string
{
    return preg_replace_callback('/([a-zA-Z])([a-zA-Z\']*)/', function (array $m): string {
        return strtoupper($m[1]) . strtolower($m[2]);
    }, $str);
}

// Mirrors validateCharacterName() in data/scripts/eventcallbacks/account_manager.lua.
function validateCharacterName(string $name): ?string
{
    $length = strlen($name);
    if ($length < CHARACTER_NAME_MIN_LENGTH) {
        return 'Character name is too short.';
    }
    if ($length > CHARACTER_NAME_MAX_LENGTH) {
        return 'Character name is too long.';
    }
    if (!preg_match('/^[a-zA-Z ]+$/', $name)) {
        return 'Character name may only contain letters and spaces.';
    }
    if (titleCase($name) !== $name) {
        return 'Each word must start with a capital letter, e.g. "John Doe".';
    }

    $words = preg_split('/\s+/', trim($name));
    if (count($words) > CHARACTER_NAME_MAX_WORDS) {
        return 'Character name has too many words.';
    }
    foreach ($words as $word) {
        $wordLength = strlen($word);
        if ($wordLength < CHARACTER_NAME_MIN_LENGTH) {
            return 'Each word must be at least ' . CHARACTER_NAME_MIN_LENGTH . ' characters.';
        }
        if ($wordLength > CHARACTER_NAME_MAX_LENGTH) {
            return 'Each word must be at most ' . CHARACTER_NAME_MAX_LENGTH . ' characters.';
        }
    }
    return null;
}

// Mirrors CreateCharacter() in data/scripts/eventcallbacks/account_manager.lua —
// keep the inserted columns/values in sync so web-created characters match
// NPC-created ones exactly.
function createCharacter(int $accountId, string $name, int $sex, int $vocationId, string $ip): void
{
    $lookType = $sex === SEX_FEMALE ? CHARACTER_DEFAULT['OUTFIT_FEMALE'] : CHARACTER_DEFAULT['OUTFIT_MALE'];
    $skill = CHARACTER_DEFAULT['SKILL'];
    $stmt = db()->prepare(
        'INSERT INTO `players` (`name`, `account_id`, `vocation`, `health`, `healthmax`, `lookbody`, `lookfeet`,
            `lookhead`, `looklegs`, `looktype`, `lookaddons`, `maglevel`, `mana`, `manamax`, `sex`, `town_id`,
            `posx`, `posy`, `posz`, `cap`, `lastip`, `stamina`, `skill_fist`, `skill_club`, `skill_sword`,
            `skill_axe`, `skill_dist`, `skill_shielding`, `skill_fishing`)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $name, $accountId, $vocationId,
        CHARACTER_DEFAULT['HEALTH'], CHARACTER_DEFAULT['HEALTH'],
        CHARACTER_DEFAULT['OUTFIT_BODY'], CHARACTER_DEFAULT['OUTFIT_FEET'],
        CHARACTER_DEFAULT['OUTFIT_HEAD'], CHARACTER_DEFAULT['OUTFIT_LEGS'],
        $lookType, CHARACTER_DEFAULT['OUTFIT_ADDONS'],
        0, CHARACTER_DEFAULT['MANA'], CHARACTER_DEFAULT['MANA'],
        $sex, CHARACTER_DEFAULT['TOWN'],
        CHARACTER_DEFAULT['POSX'], CHARACTER_DEFAULT['POSY'], CHARACTER_DEFAULT['POSZ'],
        CHARACTER_DEFAULT['CAPACITY'], ip2long($ip), CHARACTER_DEFAULT['STAMINA'],
        $skill, $skill, $skill, $skill, $skill, $skill, $skill,
    ]);
}

function currentAccount(): ?array
{
    if (empty($_SESSION['account_id'])) {
        return null;
    }
    $stmt = db()->prepare('SELECT `id`, `name`, `email`, `type`, `premium_ends_at` FROM `accounts` WHERE `id` = ?');
    $stmt->execute([$_SESSION['account_id']]);
    $account = $stmt->fetch();
    return $account ?: null;
}

function requireLogin(): array
{
    $account = currentAccount();
    if (!$account) {
        header('Location: login.php');
        exit;
    }
    return $account;
}

function vocationName(int $id): string
{
    return VOCATIONS[$id] ?? 'Unknown';
}

function onlinePlayerCount(): int
{
    return (int) db()->query('SELECT COUNT(*) FROM `players_online`')->fetchColumn();
}

function csrfToken(): string
{
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function checkCsrf(): bool
{
    return isset($_POST['csrf_token']) && hash_equals($_SESSION['csrf_token'] ?? '', $_POST['csrf_token']);
}

function onlinePlayers(): array
{
    return db()->query(
        'SELECT `p`.`name`, `p`.`level`, `p`.`vocation`
         FROM `players_online` `o`
         JOIN `players` `p` ON `p`.`id` = `o`.`player_id`
         ORDER BY `p`.`level` DESC, `p`.`name` ASC'
    )->fetchAll();
}
