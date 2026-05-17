const std = @import("std");
const render = @import("render.zig");
const terminal = @import("terminal.zig");
const FPS = @import("main.zig").FPS;
const ROWS = terminal.MIN_ROWS;
const COLS = terminal.MIN_COLS;

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
    mode: Mode,
    lazers: [MAX_LAZERS]Point,
    lazer_count: usize,
    aliens: [MAX_ALIENS]Point,
    alien_count: usize,
    tick_counter: u64,
    rng: std.Random.DefaultPrng,

    pub fn init(seed: u64) GameState {
        return .{
            .player_col = COLS / 2,
            .mode = .start_screen,
            .lazers = undefined,
            .lazer_count = 0,
            .aliens = undefined,
            .alien_count = 0,
            .tick_counter = 0,
            .rng = .init(seed),
        };
    }

    fn moveLeft(self: *GameState) void {
        if (self.player_col > 0) {
            self.player_col -= 1;
        }
    }

    fn moveRight(self: *GameState) void {
        if (self.player_col + 1 < COLS) {
            self.player_col += 1;
        }
    }

    fn randomCol(self: *GameState) usize {
        return self.rng.random().intRangeAtMost(usize, 0, COLS - 1);
    }

    fn spawnAliens(self: *GameState) void {
        var mask: u64 = 0;
        var spawned: usize = 0;

        while (spawned < 5 and self.alien_count < MAX_ALIENS) {
            const col = self.randomCol();

            const bit: u64 = @as(u64, 1) << @intCast(col);
            if ((mask & bit) != 0) continue;

            mask |= bit;

            self.aliens[self.alien_count] = Point.init(0, col);
            self.alien_count += 1;

            spawned += 1;
        }
    }

    fn updateAliens(self: *GameState) void {
        var i: usize = 0;

        while (i < self.alien_count) : (i += 1) {
            if (self.aliens[i].row == ROWS - 1) {
                // remove by swapping with last
                self.aliens[i] = self.aliens[self.alien_count - 1];
                self.alien_count -= 1;
                continue;
            }

            self.aliens[i].row += 1;
        }
    }

    fn spawnLaser(self: *GameState) void {
        if (self.lazer_count >= MAX_LAZERS) return;

        self.lazers[self.lazer_count] = Point.init(ROWS - 2, self.player_col);
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

        //update aliens
        if (self.tick_counter % FPS == 0) {
            self.updateAliens();
            self.spawnAliens();
        }
        for (self.aliens[0..self.alien_count]) |alien| {
            buff.set(alien.row, alien.col, glyph(.alien));
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
