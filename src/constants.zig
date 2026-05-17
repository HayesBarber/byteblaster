pub const dt_ns = 16_666_667;
pub const FPS = 60;
pub const ALIEN_SPEED = (FPS / 3);

pub const ROWS = 24;
pub const COLS = 48;
pub const MIN_ROWS = ROWS + 8;
pub const MIN_COLS = COLS + 8;

pub const MAX_LAZERS = 64;
pub const MAX_ALIENS = 512;

pub const start_screen =
    \\█▄▄ █▄█ ▀█▀ █▀▀ █▄▄ █   ▄▀█ █▀▀ ▀█▀ █▀▀ █▀█
    \\█▄█  █   █  ██▄ █▄█ █▄▄ █▀█ ▄▄█  █  ██▄ █▀▄
    \\
    \\Press <Space> to start
    \\<j> and <k> to move left and right
    \\<f> to fire
    \\<esc> to exit
;

pub const frame = blk: {
    const top = "┌" ++ ("─" ** COLS) ++ "┐\n";
    const mid = "│" ++ (" " ** COLS) ++ "│\n";
    const bot = "└" ++ ("─" ** COLS) ++ "┘";

    break :blk top ++ (mid ** ROWS) ++ bot;
};
