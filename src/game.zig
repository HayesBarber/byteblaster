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

const Direction = enum {
    up,
    down,
};

const OccupancyGridStatus = enum {
    enabled,
    disabled,
};

const OccupancyGridError = error{
    Disabled,
};

pub const EntityPool = struct {
    points: []Point,
    count: usize,
    direction: Direction,
    occupancy_grid_status: OccupancyGridStatus,
    occupancy_grid: [ROWS]u64,

    pub fn init(storage: []Point, direction: Direction, status: OccupancyGridStatus) EntityPool {
        return .{
            .points = storage,
            .count = 0,
            .direction = direction,
            .occupancy_grid_status = status,
            .occupancy_grid = undefined,
        };
    }

    pub fn update(self: *EntityPool) void {
        const grid_enabled = self.occupancy_grid_status == OccupancyGridStatus.enabled;
        if (grid_enabled) {
            self.occupancy_grid = [_]u64{0} ** ROWS;
        }

        var i: usize = 0;
        while (i < self.count) : (i += 1) {
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

            if (grid_enabled) {
                self.occupancy_grid[self.points[i].row] |= (@as(u64, 1) << @intCast(self.points[i].col));
            }
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

    pub fn checkCollisionsWith(self: *EntityPool, other: *EntityPool) OccupancyGridError!u16 {
        if (other.occupancy_grid_status != OccupancyGridStatus.enabled) {
            return error.Disabled;
        }

        var i: usize = 0;
        var collisions: u16 = 0;

        while (i < self.count) {
            const point = self.points[i];
            const mask = (@as(u64, 1) << @intCast(point.col));
            if ((other.occupancy_grid[point.row] & mask) != 0) {
                other.occupancy_grid[point.row] &= ~mask;
                for (other.points[0..other.count], 0..) |other_point, j| {
                    if (other_point.row == point.row and other_point.col == point.col) {
                        other.remove(j);
                        break;
                    }
                }
                self.remove(i);
                collisions += 1;
                continue;
            }
            i += 1;
        }

        return collisions;
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
        };
        state.lazers = EntityPool.init(&state.lazer_storage, .up, .disabled);
        state.aliens = EntityPool.init(&state.alien_storage, .down, .enabled);
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

    pub fn tick(self: *GameState, buff: *render.ScreenBuff, input: terminal.GameInput) void {
        if (self.mode != Mode.playing and input != .space) return;
        self.tick_counter += 1;

        if (self.tick_counter > 1) {
            _ = self.lazers.checkCollisionsWith(&self.aliens) catch {};
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
            self.aliens.update();
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
