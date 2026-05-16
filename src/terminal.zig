const std = @import("std");
const Io = std.Io;
const posix = std.posix;

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

pub fn enableRawMode() !posix.termios {
    const stdin_fd = posix.STDIN_FILENO;

    const original = try posix.tcgetattr(stdin_fd);
    var raw = original;

    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;

    try posix.tcsetattr(
        stdin_fd,
        .FLUSH,
        raw,
    );

    return original;
}

pub fn disableRawMode(original: posix.termios) !void {
    try posix.tcsetattr(
        posix.STDIN_FILENO,
        .FLUSH,
        original,
    );
}

pub fn handleInput(writer: *Io.Writer) !void {
    var buf: [1]u8 = undefined;

    while (true) {
        _ = try posix.read(posix.STDIN_FILENO, &buf);

        switch (buf[0]) {
            'j' => {
                try writer.print("j", .{});
                try writer.flush();
            },
            27 => {
                return;
            },
            else => {},
        }
    }
}
