pub const DT_NS = 16_666_667;
pub const FPS = 60;
pub const ALIEN_SPEED = (FPS / 3);

pub const ROWS = 24;
pub const COLS = 48;
pub const MIN_ROWS = ROWS + 8;
pub const MIN_COLS = COLS + 8;

pub const MAX_LAZERS = 64;
pub const MAX_ALIENS = 512;

pub const STDOUT_BUFFER_SIZE = (ROWS + 2) * (COLS + 2) * 16;

pub const START_SCREEN =
    \\█▄▄ █▄█ ▀█▀ █▀▀ █▄▄ █   ▄▀█ █▀▀ ▀█▀ █▀▀ █▀█
    \\█▄█  █   █  ██▄ █▄█ █▄▄ █▀█ ▄▄█  █  ██▄ █▀▄
    \\
    \\Press <Space> to start
    \\<j> and <k> to move left and right
    \\<f> to fire
    \\<esc> to exit
;

pub const GAME_FRAME = blk: {
    const top = "╭" ++ ("─" ** COLS) ++ "╮\n";
    const mid = "│" ++ (" " ** COLS) ++ "│\n";
    const bot = "╰" ++ ("─" ** COLS) ++ "╯";

    break :blk top ++ (mid ** ROWS) ++ bot;
};

pub const FRAME_ROWS = ROWS + 2;
pub const FRAME_COLS = COLS + 2;
