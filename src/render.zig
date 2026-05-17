const std = @import("std");
const Io = std.Io;
const terminal = @import("terminal.zig");
const game = @import("game.zig");

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
    writer: *Io.Writer,
    r_offset: usize,
    c_offset: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        rows: usize,
        cols: usize,
        writer: *Io.Writer,
        r_offset: usize,
        c_offset: usize,
    ) !ScreenBuff {
        const data = try allocator.alloc(Cell, rows * cols);

        for (data) |*cell| {
            cell.set(" ");
        }

        return .{
            .rows = rows,
            .cols = cols,
            .data = data,
            .writer = writer,
            .r_offset = r_offset,
            .c_offset = c_offset,
        };
    }

    pub fn clear(self: *ScreenBuff) void {
        for (self.data) |*cell| {
            cell.set(" ");
        }
    }

    pub fn loadString(self: *ScreenBuff, text: []const u8) !game.Point {
        var lines = std.mem.splitScalar(u8, text, '\n');
        var first_non_empty = game.Point{ .row = 0, .col = 0 };
        var found_first_non_empty = false;

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
                if (!found_first_non_empty and !std.mem.eql(u8, glyph, " ")) {
                    found_first_non_empty = true;
                    first_non_empty.col = col + self.c_offset;
                    first_non_empty.row = row + self.r_offset;
                }
                col += 1;
            }

            row += 1;
        }

        return first_non_empty;
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

    pub fn render(self: *const ScreenBuff) !void {
        for (0..self.rows) |r| {
            for (0..self.cols) |c| {
                const curr_cell = self.get(r, c);

                try terminal.printANSI(self.writer, terminal.ANSICode.move_cursor, .{ r + self.r_offset + 1, c + self.c_offset + 1 });
                try self.writer.writeAll(curr_cell.slice());
            }
        }
    }

    pub fn renderDiff(self: *const ScreenBuff, other: *const ScreenBuff) !void {
        std.debug.assert(self.rows == other.rows and self.cols == other.cols);

        for (0..self.rows) |r| {
            for (0..self.cols) |c| {
                const curr_cell = self.get(r, c);
                const prev_cell = other.get(r, c);

                if (!curr_cell.equals(prev_cell)) {
                    try terminal.printANSI(self.writer, terminal.ANSICode.move_cursor, .{ r + self.r_offset + 1, c + self.c_offset + 1 });
                    try self.writer.writeAll(curr_cell.slice());
                }
            }
        }
    }
};
