const std = @import("std");
const Io = std.Io;

pub const ANSI_Code = enum {
    enter_alternate_buffer,
    exit_alternate_buffer,
    clear_screen,
    hide_cursor,
};

fn codeToRaw(code: ANSI_Code) []const u8 {
    return switch (code) {
        ANSI_Code.enter_alternate_buffer => "\x1b[?1049h",
        ANSI_Code.exit_alternate_buffer => "\x1b[?1049l",
        ANSI_Code.clear_screen => "\x1b[2J",
        ANSI_Code.hide_cursor => "\x1b[?25l",
    };
}

pub fn printANSICode(writer: *Io.Writer, comptime code: ANSI_Code) !void {
    try writer.print(codeToRaw(code), .{});
    try writer.flush();
}
