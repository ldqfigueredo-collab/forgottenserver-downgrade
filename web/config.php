<?php
// Site + database configuration for the account website.
// Database values mirror docker-compose.yml / config.lua — keep them in sync by hand.

const DB_HOST = 'db';
const DB_PORT = 3306;
const DB_NAME = 'forgottenserver';
const DB_USER = 'tfs';
const DB_PASS = 'tfspass';

// Public-facing server info shown on the site. Update IP/domain for a real deployment —
// config.lua's `ip = "127.0.0.1"` is only meaningful to the server process itself.
const SERVER_NAME = 'Forgotten';
const SERVER_HOST = '127.0.0.1';
const SERVER_GAME_PORT = 7172;
const SERVER_WORLD_TYPE = 'PvP';

// Must mirror the validation rules in data/scripts/eventcallbacks/account_manager.lua
// so accounts created here behave identically to ones created via the in-game
// Account Manager NPC.
const ACCOUNT_NAME_MIN_LENGTH = 3;
const ACCOUNT_NAME_MAX_LENGTH = 20;
const PASSWORD_MIN_LENGTH = 6;
const PASSWORD_MAX_LENGTH = 30;

// id => display name, mirrors data/XML/vocations.xml. Update by hand if vocations change.
const VOCATIONS = [
    0 => 'None',
    1 => 'Sorcerer',
    2 => 'Druid',
    3 => 'Paladin',
    4 => 'Knight',
    5 => 'Master Sorcerer',
    6 => 'Elder Druid',
    7 => 'Royal Paladin',
    8 => 'Elite Knight',
    9 => 'Assassin',
    10 => 'Nightblade',
];

// Base vocations selectable at character creation — mirrors the choices the
// in-game Account Manager offers (data/scripts/eventcallbacks/account_manager.lua);
// promotions and Assassin/Nightblade are earned in-game, not chosen at creation.
const CREATABLE_VOCATIONS = [
    1 => 'Sorcerer',
    2 => 'Druid',
    3 => 'Paladin',
    4 => 'Knight',
];

const SEX_FEMALE = 0;
const SEX_MALE = 1;

// Mirrors validateCharacterName()/CHARACTER_NAME_* in account_manager.lua.
const CHARACTER_NAME_MIN_LENGTH = 3;
const CHARACTER_NAME_MAX_LENGTH = 20;
const CHARACTER_NAME_MAX_WORDS = 3;

// Mirrors CHARACTER_DEFAULT in account_manager.lua — keep in sync so characters
// created here start out identical to ones created via the in-game NPC.
const CHARACTER_DEFAULT = [
    'TOWN' => 1,
    'POSX' => 1000,
    'POSY' => 1000,
    'POSZ' => 7,
    'HEALTH' => 185,
    'MANA' => 35,
    'CAPACITY' => 420,
    'SKILL' => 10,
    'STAMINA' => 2520,
    'OUTFIT_MALE' => 128,
    'OUTFIT_FEMALE' => 136,
    'OUTFIT_ADDONS' => 0,
    'OUTFIT_HEAD' => 0,
    'OUTFIT_BODY' => 0,
    'OUTFIT_LEGS' => 0,
    'OUTFIT_FEET' => 0,
];

session_start();
