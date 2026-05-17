const std = @import("std");
const Io = std.Io;

const terminal = @import("terminal.zig");
const render = @import("render.zig");
const game = @import("game.zig");

const dt_ns = 16_666_667;
const start_screen =
    \\
    \\
    \\
    \\█▄▄ █▄█ ▀█▀ █▀▀ █▄▄ █   ▄▀█ █▀▀ ▀█▀ █▀▀ █▀█
    \\█▄█  █   █  ██▄ █▄█ █▄▄ █▀█ ▄▄█  █  ██▄ █▀▄
    \\
    \\Press <Space> to start
    \\<j> and <k> to move left and right
    \\<f> to fire
    \\<esc> to exit
;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &.{});
    const stdout_writer = &stdout_file_writer.interface;

    const size = terminal.getSize() catch |e| {
        switch (e) {
            error.FailedToGetSize => try stdout_writer.print("Failed to get terminal window size\n", .{}),
            error.TooFewColumns => try stdout_writer.print("Too few terminal columns\n", .{}),
            error.TooFewRows => try stdout_writer.print("Too few terminal rows\n", .{}),
        }
        return;
    };

    const original = try terminal.enableRawMode();
    defer terminal.disableRawMode(original) catch {};

    try terminal.printANSICode(stdout_writer, terminal.ANSICode.hide_cursor);
    try terminal.printANSICode(stdout_writer, terminal.ANSICode.enter_alternate_buffer);
    defer {
        terminal.printANSICode(stdout_writer, terminal.ANSICode.exit_alternate_buffer) catch {};
        terminal.printANSICode(stdout_writer, terminal.ANSICode.show_cursor) catch {};
    }

    const allocator = init.gpa;
    var prev_buff: render.ScreenBuff = try .init(allocator, size.rows, size.cols);
    var curr_buff: render.ScreenBuff = try .init(allocator, size.rows, size.cols);
    defer {
        prev_buff.deinit(allocator);
        curr_buff.deinit(allocator);
    }

    try curr_buff.loadString(start_screen);
    try render.renderBuff(&prev_buff, &curr_buff, stdout_writer);
    @memcpy(prev_buff.data, curr_buff.data);

    var seed_buffer: [64]u8 = undefined;
    io.random(&seed_buffer);
    const seed = std.mem.readInt(u64, &seed_buffer, .little);
    var game_state = game.GameState.init(size.rows, size.cols, seed);

    while (true) {
        const frame_start = std.Io.Timestamp.now(io, .real).toNanoseconds();

        const input = terminal.pollInput() catch break;
        if (input == .esc) break;

        game_state.tick(&curr_buff, input);

        try render.renderBuff(&prev_buff, &curr_buff, stdout_writer);

        std.mem.swap(render.ScreenBuff, &prev_buff, &curr_buff);

        const elapsed = std.Io.Timestamp.now(io, .real).toNanoseconds() - frame_start;
        if (elapsed < dt_ns) {
            const remaining = dt_ns - elapsed;
            io.sleep(std.Io.Duration.fromNanoseconds(remaining), .awake) catch {};
        }
    }
}
