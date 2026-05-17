const std = @import("std");
const render = @import("render.zig");
const terminal = @import("terminal.zig");
const FPS = @import("main.zig").FPS;
const ROWS = terminal.MIN_ROWS;
const COLS = terminal.MIN_COLS;

const MAX_LAZERS = 64;
const MAX_ALIENS = 512;

const ALIEN_SPEED = (FPS / 3);

pub const Point = struct {
    row: usize,
    col: usize,

    pub fn init(row: usize, col: usize) Point {
        return .{
            .row = row,
            .col = col,
        };
    }

    fn moveLeft(self: *Point) void {
        if (self.col > 0) {
            self.col -= 1;
        }
    }

    fn moveRight(self: *Point) void {
        if (self.col + 1 < COLS) {
            self.col += 1;
        }
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
    entity: Entity,

    pub fn init(entity: Entity, storage: []Point, direction: Direction, status: OccupancyGridStatus) EntityPool {
        return .{
            .entity = entity,
            .points = storage,
            .count = 0,
            .direction = direction,
            .occupancy_grid_status = status,
            .occupancy_grid = undefined,
        };
    }

    pub fn draw(self: *EntityPool, buff: *render.ScreenBuff) void {
        for (self.points[0..self.count]) |point| {
            buff.set(point.row, point.col, glyph(self.entity));
        }
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

    pub fn collidingWithPoint(self: *EntityPool, point: *Point) bool {
        std.debug.assert(self.occupancy_grid_status == OccupancyGridStatus.enabled);

        const mask = (@as(u64, 1) << @intCast(point.col));
        return (self.occupancy_grid[point.row] & mask) != 0;
    }

    pub fn checkCollisionsWith(self: *EntityPool, other: *EntityPool) u16 {
        std.debug.assert(other.occupancy_grid_status == OccupancyGridStatus.enabled);

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
    player_pos: Point,
    mode: Mode,
    lazer_storage: [MAX_LAZERS]Point,
    alien_storage: [MAX_ALIENS]Point,
    lazers: EntityPool,
    aliens: EntityPool,
    tick_counter: u64,
    rng: std.Random.DefaultPrng,

    pub fn init(seed: u64) GameState {
        var state = GameState{
            .player_pos = Point.init(ROWS - 1, COLS / 2),
            .mode = .start_screen,
            .lazer_storage = undefined,
            .alien_storage = undefined,
            .lazers = undefined,
            .aliens = undefined,
            .tick_counter = 0,
            .rng = .init(seed),
        };
        state.lazers = EntityPool.init(.lazer, &state.lazer_storage, .up, .disabled);
        state.aliens = EntityPool.init(.alien, &state.alien_storage, .down, .enabled);
        return state;
    }

    pub fn tick(self: *GameState, buff: *render.ScreenBuff, input: terminal.GameInput) bool {
        if (self.mode != Mode.playing and input != .space) return false;
        self.tick_counter += 1;

        if (self.tick_counter > 1) {
            _ = self.lazers.checkCollisionsWith(&self.aliens);
            // game over
            if (self.aliens.collidingWithPoint(&self.player_pos)) {
                self.mode = .start_screen;
                return true;
            }
        }

        buff.clear();

        switch (input) {
            .j => self.player_pos.moveLeft(),
            .k => self.player_pos.moveRight(),
            .f => _ = self.lazers.spawn(ROWS - 1, self.player_pos.col),
            .space => self.mode = .playing,
            else => {},
        }

        buff.set(self.player_pos.row, self.player_pos.col, glyph(.player));

        self.lazers.update();
        self.lazers.draw(buff);

        if (self.tick_counter % ALIEN_SPEED == 0) {
            self.aliens.update();
            self.aliens.spawnRandom(0, COLS, 5, &self.rng);
        }
        self.aliens.draw(buff);

        return false;
    }
};

pub const Entity = enum {
    player,
    alien,
    lazer,
    empty,
};

pub fn glyph(e: Entity) []const u8 {
    return switch (e) {
        .player => "▲",
        .alien => "■",
        .lazer => "│",
        .empty => " ",
    };
}

pub const Mode = enum {
    start_screen,
    playing,
};
