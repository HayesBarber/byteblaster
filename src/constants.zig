pub const DT_NS = 16_666_667;
pub const FPS = 60;
pub const ALIEN_SPEED = (FPS / 3);
pub const RELOAD_SPEED = (FPS / 1);
pub const LEVEL_SPEED = (FPS * 10);

pub const GAME_ROWS = 24;
pub const GAME_COLS = 48;
pub const STATS_ROWS = 1;
pub const STATS_COLS = GAME_COLS;
pub const MIN_ROWS = GAME_ROWS + STATS_ROWS + 8;
pub const MIN_COLS = GAME_COLS + 8;

pub const MAX_LAZERS = 64;
pub const MAX_ALIENS = 512;
pub const MAX_AMMO = 5;

// ~14 B per cell (ANSI escape + content) for a full playfield render
pub const STDOUT_BUFFER_SIZE = GAME_ROWS * GAME_COLS * 16;

pub const START_SCREEN =
    \\█▄▄ █▄█ ▀█▀ █▀▀ █▄▄ █   ▄▀█ █▀▀ ▀█▀ █▀▀ █▀█
    \\█▄█  █   █  ██▄ █▄█ █▄▄ █▀█ ▄▄█  █  ██▄ █▀▄
    \\
    \\Press <Space> to start
    \\<j> and <k> to move left and right
    \\<f> to fire
    \\<esc> to exit
;

pub const STATS =
    \\Ammo: {d}
    \\Score: {d}
    \\Level: {d}
;

pub const GAME_FRAME = blk: {
    const top = "╭" ++ ("─" ** GAME_COLS) ++ "╮\n";
    const mid = "│" ++ (" " ** GAME_COLS) ++ "│\n";
    const bot = "╰" ++ ("─" ** GAME_COLS) ++ "╯";

    break :blk top ++ (mid ** GAME_ROWS) ++ bot;
};

pub const STATS_FRAME = blk: {
    const top = "╭" ++ ("─" ** STATS_COLS) ++ "╮\n";
    const mid = "│" ++ (" " ** STATS_COLS) ++ "│\n";
    const bot = "╰" ++ ("─" ** STATS_COLS) ++ "╯";

    break :blk top ++ (mid ** STATS_ROWS) ++ bot;
};

pub const FRAME_ROWS = GAME_ROWS + 2;
pub const FRAME_COLS = GAME_COLS + 2;
pub const STATS_FRAME_ROWS = STATS_ROWS + 2;
pub const STATS_FRAME_COLS = STATS_COLS + 2;
