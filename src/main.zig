const std = @import("std");
const Io = std.Io;

const terminal = @import("terminal.zig");
const render = @import("render.zig");
const game = @import("game.zig");

const dt_ns = 16_666_667;
pub const FPS = 60;
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

    _ = terminal.getSize() catch |e| {
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
    var prev_buff: render.ScreenBuff = try .init(allocator, game.ROWS, game.COLS);
    var curr_buff: render.ScreenBuff = try .init(allocator, game.ROWS, game.COLS);
    defer {
        prev_buff.deinit(allocator);
        curr_buff.deinit(allocator);
    }

    try loadStartScreen(&prev_buff, &curr_buff, stdout_writer, 0, 0);
    var game_state = createGameState(&io);

    while (true) {
        const frame_start = std.Io.Timestamp.now(io, .real).toNanoseconds();

        const input = terminal.pollInput() catch break;
        if (input == .esc) break;

        if (game_state.tick(&curr_buff, input)) {
            try loadStartScreen(&prev_buff, &curr_buff, stdout_writer, 0, 0);
            game_state = createGameState(&io);
        }

        try render.renderBuff(&prev_buff, &curr_buff, stdout_writer, 0, 0);

        std.mem.swap(render.ScreenBuff, &prev_buff, &curr_buff);

        const elapsed = std.Io.Timestamp.now(io, .real).toNanoseconds() - frame_start;
        if (elapsed < dt_ns) {
            const remaining = dt_ns - elapsed;
            io.sleep(std.Io.Duration.fromNanoseconds(remaining), .awake) catch {};
        }
    }
}

fn loadStartScreen(prev: *render.ScreenBuff, curr: *render.ScreenBuff, writer: *Io.Writer, r_offset: usize, c_offset: usize) !void {
    curr.clear();
    try curr.loadString(start_screen);
    try render.renderBuff(prev, curr, writer, r_offset, c_offset);
    @memcpy(prev.data, curr.data);
}

fn createGameState(io: *const std.Io) game.GameState {
    var seed_buffer: [8]u8 = undefined;
    io.random(&seed_buffer);
    const seed = std.mem.readInt(u64, &seed_buffer, .little);
    const game_state = game.GameState.init(seed);
    return game_state;
}
