const std = @import("std");
const Io = std.Io;

pub const ANSII_Code = enum {
    enter_alternate_buffer,
    exit_alternate_buffer,
    clear_screen,
    hide_cursor,
};

fn codeToRaw(code: ANSII_Code) []const u8 {
    return switch (code) {
        ANSII_Code.enter_alternate_buffer => "\x1b[?1049h",
        ANSII_Code.exit_alternate_buffer => "\x1b[?1049l",
        ANSII_Code.clear_screen => "\x1b[2J",
        ANSII_Code.hide_cursor => "\x1b[?25l",
    };
}

pub fn printANSIICode(writer: *Io.Writer, comptime code: ANSII_Code) !void {
    try writer.print(codeToRaw(code), .{});
    try writer.flush();
}
