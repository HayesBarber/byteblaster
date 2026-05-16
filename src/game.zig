const render = @import("render.zig");
const terminal = @import("terminal.zig");

const MAX_LAZERS = 64;
const MAX_ALIENS = 512;

pub const Point = struct {
    row: usize,
    col: usize,

    pub fn init(row: usize, col: usize) Point {
        return .{
            .row = row,
            .col = col,
        };
    }
};

pub const GameState = struct {
    player_col: usize,
    cols: usize,
    rows: usize,
    mode: Mode,
    lazers: [MAX_LAZERS]Point,
    lazer_count: usize,
    aliens: [MAX_LAZERS]Point,
    alien_count: usize,
    tick_counter: u64,

    pub fn init(rows: usize, cols: usize) GameState {
        return .{
            .player_col = cols / 2,
            .cols = cols,
            .rows = rows,
            .mode = .start_screen,
            .lazers = undefined,
            .lazer_count = 0,
            .aliens = undefined,
            .alien_count = 0,
            .tick_counter = 0,
        };
    }

    fn moveLeft(self: *GameState) void {
        if (self.player_col > 0) {
            self.player_col -= 1;
        }
    }

    fn moveRight(self: *GameState) void {
        if (self.player_col + 1 < self.cols) {
            self.player_col += 1;
        }
    }

    fn spawnLaser(self: *GameState) void {
        if (self.lazer_count >= MAX_LAZERS) return;

        self.lazers[self.lazer_count] = Point.init(self.rows - 2, self.player_col);
        self.lazer_count += 1;
    }

    pub fn updateLazers(self: *GameState) void {
        var i: usize = 0;

        while (i < self.lazer_count) : (i += 1) {
            if (self.lazers[i].row == 0) {
                // remove by swapping with last
                self.lazers[i] = self.lazers[self.lazer_count - 1];
                self.lazer_count -= 1;
                continue;
            }

            self.lazers[i].row -= 1;
        }
    }

    pub fn tick(self: *GameState, buff: *render.ScreenBuff, input: terminal.GameInput) void {
        self.tick_counter += 1;
        if (self.mode != Mode.playing and input != .space) return;

        buff.clear();

        switch (input) {
            .j => self.moveLeft(),
            .k => self.moveRight(),
            .f => self.spawnLaser(),
            .space => self.mode = .playing,
            else => {},
        }

        // update player
        buff.set(buff.rows - 1, self.player_col, glyph(.player));

        //update lazers
        self.updateLazers();
        for (self.lazers[0..self.lazer_count]) |l| {
            buff.set(l.row, l.col, glyph(.laser));
        }
    }
};

pub const Entity = enum {
    player,
    alien,
    laser,
    empty,
};

pub fn glyph(e: Entity) []const u8 {
    return switch (e) {
        .player => "▲",
        .alien => "■",
        .laser => "│",
        .empty => " ",
    };
}

pub const Mode = enum {
    start_screen,
    playing,
    game_over,
};
