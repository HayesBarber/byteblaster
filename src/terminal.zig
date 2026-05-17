const std = @import("std");
const Io = std.Io;
const posix = std.posix;

pub const MIN_ROWS = 24;
pub const MIN_COLS = 48;

pub const ANSICode = enum {
    enter_alternate_buffer,
    exit_alternate_buffer,
    clear_screen,
    hide_cursor,
    show_cursor,
    move_cursor,
};

pub const GameInput = enum(i16) {
    noop = -1,
    j = 'j',
    k = 'k',
    f = 'f',
    esc = 27,
    space = 32,
    _,
};

fn codeToRaw(code: ANSICode) []const u8 {
    return switch (code) {
        .enter_alternate_buffer => "\x1b[?1049h",
        .exit_alternate_buffer => "\x1b[?1049l",
        .clear_screen => "\x1b[2J",
        .hide_cursor => "\x1b[?25l",
        .show_cursor => "\x1b[?25h",
        .move_cursor => "\x1b[{d};{d}H",
    };
}

fn parseInput(byte: u8) GameInput {
    return @enumFromInt(byte);
}

pub fn printANSICode(writer: *Io.Writer, comptime code: ANSICode) !void {
    try printANSI(writer, code, .{});
}

pub fn printANSI(writer: *Io.Writer, comptime code: ANSICode, args: anytype) !void {
    try writer.print(codeToRaw(code), args);
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

pub fn pollInput() !GameInput {
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
    if (n == 0) return GameInput.noop;

    // stdin not readable
    if ((fds[0].revents & posix.POLL.IN) == 0) return GameInput.noop;

    var buf: [1]u8 = undefined;
    _ = try posix.read(posix.STDIN_FILENO, &buf);

    return parseInput(buf[0]);
}

pub const WinSize = struct {
    cols: usize = 0,
    rows: usize = 0,
    failed: u1 = 0,
};

pub const TerminalError = error{
    TooFewColumns,
    TooFewRows,
    FailedToGetSize,
};

pub fn getSize() TerminalError!WinSize {
    const fd = Io.File.stdout().handle;
    var winsize = posix.winsize{
        .row = 0,
        .col = 0,
        .xpixel = 0,
        .ypixel = 0,
    };

    const err = posix.system.ioctl(fd, posix.T.IOCGWINSZ, @intFromPtr(&winsize));

    if (posix.errno(err) != .SUCCESS) {
        return TerminalError.FailedToGetSize;
    }

    const size = WinSize{
        .cols = @min(winsize.col, MIN_COLS),
        .rows = @min(winsize.row, MIN_ROWS),
    };

    if (size.cols < MIN_COLS) {
        return TerminalError.TooFewColumns;
    } else if (size.rows < MIN_ROWS) {
        return TerminalError.TooFewRows;
    }

    return size;
}
