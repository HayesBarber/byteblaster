const render = @import("render.zig");
const terminal = @import("terminal.zig");

pub const GameState = struct {
    player_col: usize,
    cols: usize,
    rows: usize,
    mode: Mode,

    pub fn init(rows: usize, cols: usize) GameState {
        return .{
            .player_col = cols / 2,
            .cols = cols,
            .rows = rows,
            .mode = .start_screen,
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

    pub fn tick(self: *GameState, buff: *render.ScreenBuff, input: terminal.GameInput) void {
        if (self.mode != Mode.playing) return;

        buff.clear();

        switch (input) {
            .j => self.moveLeft(),
            .k => self.moveRight(),
            else => {},
        }

        buff.set(buff.rows - 1, self.player_col, glyph(.player));
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
