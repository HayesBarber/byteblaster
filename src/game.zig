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

pub const Direction = enum {
    up,
    down,
};

pub const EntityPool = struct {
    points: []Point,
    count: usize,
    direction: Direction,

    pub fn init(storage: []Point, direction: Direction) EntityPool {
        return .{
            .points = storage,
            .count = 0,
            .direction = direction,
        };
    }

    pub fn update(self: *EntityPool) void {
        var i: usize = 0;
        while (i < self.count) {
            const at_despawn = switch (self.direction) {
                .up => self.points[i].row == 0,
                .down => self.points[i].row == ROWS - 1,
            };
            if (at_despawn) {
                self.remove(i);
                continue;
            }
            switch (self.direction) {
                .up => self.points[i].row -= 1,
                .down => self.points[i].row += 1,
            }
            i += 1;
        }
    }

    pub fn remove(self: *EntityPool, index: usize) void {
        self.points[index] = self.points[self.count - 1];
        self.count -= 1;
    }

    pub fn spawn(self: *EntityPool, row: usize, col: usize) bool {
        if (self.count >= self.points.len) return false;
        self.points[self.count] = Point.init(row, col);
        self.count += 1;
        return true;
    }

    pub fn spawnRandom(self: *EntityPool, row: usize, cols: usize, count: usize, rng: *std.Random.DefaultPrng) void {
        var mask: u64 = 0;
        var spawned: usize = 0;
        while (spawned < count and self.count < self.points.len) {
            const col = rng.random().intRangeAtMost(usize, 0, cols - 1);
            const bit: u64 = @as(u64, 1) << @intCast(col);
            if ((mask & bit) != 0) continue;
            mask |= bit;
            self.points[self.count] = Point.init(row, col);
            self.count += 1;
            spawned += 1;
        }
    }
};

pub const GameState = struct {
    player_col: usize,
    mode: Mode,
    lazer_storage: [MAX_LAZERS]Point,
    alien_storage: [MAX_ALIENS]Point,
    lazers: EntityPool,
    aliens: EntityPool,
    tick_counter: u64,
    rng: std.Random.DefaultPrng,
    alien_rows: [ROWS]u64,

    pub fn init(seed: u64) GameState {
        var state = GameState{
            .player_col = COLS / 2,
            .mode = .start_screen,
            .lazer_storage = undefined,
            .alien_storage = undefined,
            .lazers = undefined,
            .aliens = undefined,
            .tick_counter = 0,
            .rng = .init(seed),
            .alien_rows = undefined,
        };
        state.lazers = EntityPool.init(&state.lazer_storage, .up);
        state.aliens = EntityPool.init(&state.alien_storage, .down);
        return state;
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

    fn updateAliens(self: *GameState) void {
        self.aliens.update();
        self.alien_rows = [_]u64{0} ** ROWS;
        for (self.aliens.points[0..self.aliens.count]) |alien| {
            self.alien_rows[alien.row] |= (@as(u64, 1) << @intCast(alien.col));
        }
    }

    fn checkLazerCollisions(self: *GameState) void {
        var lazer_i: usize = 0;
        while (lazer_i < self.lazers.count) {
            const lazer = self.lazers.points[lazer_i];
            const mask = (@as(u64, 1) << @intCast(lazer.col));
            if ((self.alien_rows[lazer.row] & mask) != 0) {
                self.alien_rows[lazer.row] &= ~mask;
                for (self.aliens.points[0..self.aliens.count], 0..) |alien, i| {
                    if (alien.row == lazer.row and alien.col == lazer.col) {
                        self.aliens.remove(i);
                        break;
                    }
                }
                self.lazers.remove(lazer_i);
                continue;
            }
            lazer_i += 1;
        }
    }

    pub fn tick(self: *GameState, buff: *render.ScreenBuff, input: terminal.GameInput) void {
        if (self.mode != Mode.playing and input != .space) return;
        self.tick_counter += 1;

        if (self.tick_counter > 1) {
            self.checkLazerCollisions();
        }

        buff.clear();

        switch (input) {
            .j => self.moveLeft(),
            .k => self.moveRight(),
            .f => _ = self.lazers.spawn(ROWS - 1, self.player_col),
            .space => self.mode = .playing,
            else => {},
        }

        buff.set(buff.rows - 1, self.player_col, glyph(.player));

        self.lazers.update();
        for (self.lazers.points[0..self.lazers.count]) |l| {
            buff.set(l.row, l.col, glyph(.laser));
        }

        if (self.tick_counter % FPS == 0) {
            self.updateAliens();
            self.aliens.spawnRandom(0, COLS, 5, &self.rng);
        }
        for (self.aliens.points[0..self.aliens.count]) |alien| {
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
};
