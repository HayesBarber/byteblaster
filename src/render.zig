const std = @import("std");
const Io = std.Io;
const terminal = @import("terminal.zig");

const start_screen =
    \\
    \\ █▄▄ █▄█ ▀█▀ █▀▀ █▄▄ █   ▄▀█ █▀▀ ▀█▀ █▀▀ █▀█
    \\ █▄█  █   █  ██▄ █▄█ █▄▄ █▀█ ▄▄█  █  ██▄ █▀▄
    \\
    \\          Press <Space> to start
    \\     <j> and <k> to move left and right
    \\               <f> to fire
    \\              <esc> to exit
;

pub const ScreenBuff = struct {
    rows: usize,
    cols: usize,
    data: []u8,

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize, is_start_screen: bool) !ScreenBuff {
        const data = try allocator.alloc(u8, rows * cols);
        @memset(data, ' ');
        if (is_start_screen) {
            var row: usize = 0;

            var lines = std.mem.splitScalar(u8, start_screen, '\n');
            while (lines.next()) |line| {
                const len = @min(line.len, cols);

                const start = row * cols;
                @memcpy(data[start .. start + len], line[0..len]);

                row += 1;
            }
        }

        return .{
            .rows = rows,
            .cols = cols,
            .data = data,
        };
    }

    pub fn deinit(self: *ScreenBuff, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    pub fn get(self: *const ScreenBuff, r: usize, c: usize) u8 {
        return self.data[r * self.cols + c];
    }

    pub fn set(self: *ScreenBuff, r: usize, c: usize, value: u8) void {
        self.data[r * self.cols + c] = value;
    }
};

pub fn renderBuff(prev: *ScreenBuff, curr: *ScreenBuff, writer: *Io.Writer) !void {
    for (0..prev.rows) |r| {
        for (0..prev.cols) |c| {
            const curr_byte = curr.get(r, c);
            const prev_byte = prev.get(r, c);

            if (curr_byte != prev_byte) {
                try terminal.printANSI(writer, terminal.ANSICode.move_cursor, .{ r + 1, c + 1 });
                try writer.writeByte(curr_byte);
            }
        }
    }
}
