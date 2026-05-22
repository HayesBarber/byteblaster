const std = @import("std");
const Io = std.Io;
const terminal = @import("terminal.zig");
const game = @import("game.zig");
const utils = @import("utils.zig");

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
    prev: []Cell,
    curr: []Cell,
    writer: *Io.Writer,
    r_offset: usize,
    c_offset: usize,
    rows: usize,
    cols: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        writer: *Io.Writer,
        r_offset: usize,
        c_offset: usize,
        comptime frame: []const u8,
    ) !ScreenBuff {
        const dim = comptime utils.dimensions(frame);
        try utils.renderComptimeArt(frame, writer, r_offset, c_offset);

        const rows = dim.rows - 2;
        const cols = dim.cols - 2;
        const prev = try allocator.alloc(Cell, rows * cols);
        const curr = try allocator.alloc(Cell, rows * cols);
        for (0..curr.len) |i| {
            prev[i].set(" ");
            curr[i].set(" ");
        }

        return .{
            .curr = curr,
            .prev = prev,
            .writer = writer,
            .r_offset = r_offset + 1,
            .c_offset = c_offset + 1,
            .rows = rows,
            .cols = cols,
        };
    }

    pub fn deinit(self: *ScreenBuff, allocator: std.mem.Allocator) void {
        allocator.free(self.prev);
        allocator.free(self.curr);
    }

    pub fn clear(self: *ScreenBuff) void {
        for (self.curr) |*cell| {
            cell.set(" ");
        }
    }

    pub fn getPrev(self: *const ScreenBuff, r: usize, c: usize) *const Cell {
        return &self.prev[r * self.cols + c];
    }

    pub fn get(self: *const ScreenBuff, r: usize, c: usize) *const Cell {
        return &self.curr[r * self.cols + c];
    }

    pub fn getMut(self: *ScreenBuff, r: usize, c: usize) *Cell {
        return &self.curr[r * self.cols + c];
    }

    pub fn set(self: *ScreenBuff, r: usize, c: usize, text: []const u8) void {
        self.getMut(r, c).set(text);
    }

    pub fn renderDiff(self: *ScreenBuff) !void {
        for (0..self.rows) |r| {
            for (0..self.cols) |c| {
                const prev_cell = self.getPrev(r, c);
                const curr_cell = self.get(r, c);

                if (!curr_cell.equals(prev_cell)) {
                    try terminal.printANSI(self.writer, terminal.ANSICode.move_cursor, .{ r + self.r_offset + 1, c + self.c_offset + 1 });
                    try self.writer.writeAll(curr_cell.slice());
                }
            }
        }

        try self.writer.flush();
        std.mem.swap([]Cell, &self.prev, &self.curr);
        self.clear();
    }

    pub fn loadString(self: *ScreenBuff, text: []const u8) !void {
        var lines = std.mem.splitScalar(u8, text, '\n');

        const line_count = std.mem.count(u8, text, "\n") + 1;
        var row: usize = 0;
        if (line_count < self.rows) {
            row = (self.rows - line_count) / 2;
        }

        while (lines.next()) |line| {
            if (row >= self.rows) break;

            // count UTF-8 glyphs in this line
            var view = std.unicode.Utf8View.initUnchecked(line);
            var it = view.iterator();

            var glyph_count: usize = 0;
            while (it.nextCodepointSlice()) |_| {
                glyph_count += 1;
            }

            const pad = if (glyph_count < self.cols)
                (self.cols - glyph_count) / 2
            else
                0;

            var col: usize = pad;

            // reset iterator for actual write
            view = std.unicode.Utf8View.initUnchecked(line);
            it = view.iterator();

            while (it.nextCodepointSlice()) |glyph| {
                if (col >= self.cols) break;

                self.set(row, col, glyph);
                col += 1;
            }

            row += 1;
        }
    }
};
