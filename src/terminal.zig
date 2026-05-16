const std = @import("std");
const Io = std.Io;
const posix = std.posix;

pub const ANSICode = enum {
    enter_alternate_buffer,
    exit_alternate_buffer,
    clear_screen,
    hide_cursor,
};

pub const GameInput = enum(u8) {
    j = 'j',
    k = 'k',
    esc = 27,
    _,
};

fn codeToRaw(code: ANSICode) []const u8 {
    return switch (code) {
        .enter_alternate_buffer => "\x1b[?1049h",
        .exit_alternate_buffer => "\x1b[?1049l",
        .clear_screen => "\x1b[2J",
        .hide_cursor => "\x1b[?25l",
    };
}

fn parseInput(byte: u8) GameInput {
    return @enumFromInt(byte);
}

pub fn printANSICode(writer: *Io.Writer, comptime code: ANSICode) !void {
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

pub fn pollInput(writer: *Io.Writer) !bool {
    var fds = [_]posix.pollfd{
        .{
            .fd = posix.STDIN_FILENO,
            .events = posix.POLL.IN,
            .revents = 0,
        },
    };

    // 0 timeout = non-blocking poll
    const n = try posix.poll(&fds, 0);

    // no input this frame
    if (n == 0) return false;

    // stdin not readable
    if ((fds[0].revents & posix.POLL.IN) == 0) return false;

    var buf: [1]u8 = undefined;
    _ = try posix.read(posix.STDIN_FILENO, &buf);

    switch (parseInput(buf[0])) {
        .j => {
            try writer.print("j", .{});
            try writer.flush();
        },
        .k => {
            try writer.print("k", .{});
            try writer.flush();
        },
        .esc => return true, // signal exit
        else => {},
    }

    return false;
}
