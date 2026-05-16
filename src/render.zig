const std = @import("std");
const Io = std.Io;
const terminal = @import("terminal.zig");

pub const Cell = struct {
    bytes: [4]u8 = .{ 0, 0, 0, 0 },
    len: u8 = 0,

    pub fn set(self: *Cell, text: []const u8) void {
        self.len = @intCast(text.len);
        @memcpy(self.bytes[0..text.len], text);
    }

    pub fn slice(self: *const Cell) []const u8 {
        return self.bytes[0..self.len];
    }

    pub fn equals(self: *const Cell, other: *const Cell) bool {
        return std.mem.eql(u8, self.slice(), other.slice());
    }
};

pub const ScreenBuff = struct {
    rows: usize,
    cols: usize,
    data: []Cell,

    pub fn init(
        allocator: std.mem.Allocator,
        rows: usize,
        cols: usize,
    ) !ScreenBuff {
        const data = try allocator.alloc(Cell, rows * cols);

        for (data) |*cell| {
            cell.set(" ");
        }

        return .{
            .rows = rows,
            .cols = cols,
            .data = data,
        };
    }

    pub fn loadString(self: *ScreenBuff, text: []const u8) !void {
        var row: usize = 0;
        var col: usize = 0;

        var iter = std.unicode.Utf8View.initUnchecked(text).iterator();

        while (iter.nextCodepointSlice()) |glyph| {
            if (std.mem.eql(u8, glyph, "\n")) {
                row += 1;
                col = 0;
                continue;
            }

            if (row >= self.rows) break;
            if (col >= self.cols) continue;

            self.set(row, col, glyph);

            col += 1;
        }
    }

    pub fn deinit(self: *ScreenBuff, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    pub fn get(self: *const ScreenBuff, r: usize, c: usize) *const Cell {
        return &self.data[r * self.cols + c];
    }

    pub fn getMut(self: *ScreenBuff, r: usize, c: usize) *Cell {
        return &self.data[r * self.cols + c];
    }

    pub fn set(self: *ScreenBuff, r: usize, c: usize, text: []const u8) void {
        self.getMut(r, c).set(text);
    }
};

pub fn renderBuff(prev: *ScreenBuff, curr: *ScreenBuff, writer: *Io.Writer) !void {
    for (0..prev.rows) |r| {
        for (0..prev.cols) |c| {
            const curr_cell = curr.get(r, c);
            const prev_cell = prev.get(r, c);

            if (!curr_cell.equals(prev_cell)) {
                try terminal.printANSI(writer, terminal.ANSICode.move_cursor, .{ r + 1, c + 1 });
                try writer.writeAll(curr_cell.slice());
            }
        }
    }
}
