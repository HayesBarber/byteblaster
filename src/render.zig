const std = @import("std");

const start_screen =
    \\
    \\ █▄▄ █▄█ ▀█▀ █▀▀ █▄▄ █   ▄▀█ █▀▀ ▀█▀ █▀▀ █▀█
    \\ █▄█  █   █  ██▄ █▄█ █▄▄ █▀█ ▄▄█  █  ██▄ █▀▄
    \\
    \\          Press <Space> to start
;

pub const ScreenBuff = struct {
    rows: usize,
    cols: usize,
    data: []u8,

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize, initial_data: []const u8) !ScreenBuff {
        const data = try allocator.alloc(u8, rows * cols);
        @memcpy(data, initial_data);

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
