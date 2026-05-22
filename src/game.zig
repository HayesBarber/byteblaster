const std = @import("std");
const Io = std.Io;
const render = @import("renderv2.zig");
const terminal = @import("terminal.zig");
const constants = @import("constants.zig");

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
        if (self.col + 1 < constants.GAME_COLS) {
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

pub const EntityPool = struct {
    points: []Point,
    count: usize,
    direction: Direction,
    occupancy_grid_status: OccupancyGridStatus,
    occupancy_grid: [constants.GAME_ROWS]u64,
    entity: Entity,

    pub fn init(entity: Entity, storage: []Point, direction: Direction, status: OccupancyGridStatus) EntityPool {
        return .{
            .entity = entity,
            .points = storage,
            .count = 0,
            .direction = direction,
            .occupancy_grid_status = status,
            .occupancy_grid = if (status == OccupancyGridStatus.enabled) [_]u64{0} ** constants.GAME_ROWS else undefined,
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
            self.occupancy_grid = [_]u64{0} ** constants.GAME_ROWS;
        }

        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            const at_despawn = switch (self.direction) {
                .up => self.points[i].row == 0,
                .down => self.points[i].row == constants.GAME_ROWS - 1,
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
    lazer_storage: [constants.MAX_LAZERS]Point,
    alien_storage: [constants.MAX_ALIENS]Point,
    lazers: EntityPool,
    aliens: EntityPool,
    tick_counter: u64,
    rng: std.Random.DefaultPrng,
    ammo: u8,
    score: usize,
    level: usize,

    pub fn init(io: *const std.Io) GameState {
        var seed_buffer: [8]u8 = undefined;
        io.random(&seed_buffer);
        const seed = std.mem.readInt(u64, &seed_buffer, .little);

        var state = GameState{
            .player_pos = Point.init(constants.GAME_ROWS - 1, constants.GAME_COLS / 2),
            .mode = .start_screen,
            .lazer_storage = undefined,
            .alien_storage = undefined,
            .lazers = undefined,
            .aliens = undefined,
            .tick_counter = 0,
            .rng = .init(seed),
            .ammo = constants.MAX_AMMO,
            .score = 0,
            .level = 0,
        };
        state.lazers = EntityPool.init(.lazer, &state.lazer_storage, .up, .disabled);
        state.aliens = EntityPool.init(.alien, &state.alien_storage, .down, .enabled);
        return state;
    }

    pub fn tick(self: *GameState, buff: *render.ScreenBuff, input: terminal.GameInput) bool {
        if (self.mode != Mode.playing and input != .space) return false;
        self.tick_counter += 1;

        _ = self.lazers.checkCollisionsWith(&self.aliens);
        // game over
        if (self.aliens.collidingWithPoint(&self.player_pos)) {
            self.mode = .start_screen;
            return true;
        }

        switch (input) {
            .j => self.player_pos.moveLeft(),
            .k => self.player_pos.moveRight(),
            .f => {
                if (self.ammo > 0) {
                    _ = self.lazers.spawn(constants.GAME_ROWS - 1, self.player_pos.col);
                    self.ammo -= 1;
                }
            },
            .space => self.mode = .playing,
            else => {},
        }

        buff.set(self.player_pos.row, self.player_pos.col, glyph(.player));

        if (self.tick_counter % constants.RELOAD_SPEED == 0) {
            self.ammo = @min(self.ammo + 1, constants.MAX_AMMO);
        }

        if (self.tick_counter % constants.LEVEL_SPEED == 0) {
            self.level += 1;
        }

        // don't update in the same tick so that they don't swap places and appear to phase through
        if (self.tick_counter % constants.ALIEN_SPEED == 0) {
            self.aliens.update();
            self.aliens.spawnRandom(0, constants.GAME_COLS, 5, &self.rng);
            self.score += 1;
        } else {
            self.lazers.update();
        }
        self.aliens.draw(buff);
        self.lazers.draw(buff);

        return false;
    }

    pub fn scoreStr(self: *GameState, buf: []u8) ![]u8 {
        return std.fmt.bufPrint(
            buf,
            constants.STATS,
            .{
                self.ammo,
                self.score,
                self.level,
            },
        );
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
