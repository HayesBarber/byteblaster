const std = @import("std");
const Io = std.Io;

const terminal = @import("terminal.zig");
const render = @import("render.zig");
const game = @import("game.zig");
const constants = @import("constants.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &.{});
    const stdout_writer = &stdout_file_writer.interface;

    const size = terminal.getSize() catch |e| {
        const msg = switch (e) {
            error.FailedToGetSize => "Failed to get terminal window size\n",
            error.TooFewColumns => "Too few terminal columns\n",
            error.TooFewRows => "Too few terminal rows\n",
        };
        try stdout_writer.writeAll(msg);
        return;
    };

    var guard = try terminal.TerminalGuard.init(stdout_writer);
    defer guard.deinit();

    var frame_buff: render.ScreenBuff = try .init(allocator, size.rows, size.cols);
    defer frame_buff.deinit(allocator);
    const game_offset = try frame_buff.loadString(constants.frame);
    try render.renderBuff(&frame_buff, stdout_writer, 0, 0);

    var prev_buff: render.ScreenBuff = try .init(allocator, constants.ROWS, constants.COLS);
    var curr_buff: render.ScreenBuff = try .init(allocator, constants.ROWS, constants.COLS);
    defer {
        prev_buff.deinit(allocator);
        curr_buff.deinit(allocator);
    }

    const offset_r = game_offset.row + 1;
    const offset_c = game_offset.col + 1;

    try resetToStartScreen(&prev_buff, &curr_buff, stdout_writer, offset_r, offset_c);
    var game_state = game.GameState.init(&io);

    while (true) {
        const frame_start = std.Io.Timestamp.now(io, .real).toNanoseconds();

        const input = terminal.pollInput() catch break;
        if (input == .esc) break;

        if (game_state.tick(&curr_buff, input)) {
            try resetToStartScreen(&prev_buff, &curr_buff, stdout_writer, offset_r, offset_c);
            game_state = game.GameState.init(&io);
        }

        try render.renderBuffDiff(&prev_buff, &curr_buff, stdout_writer, offset_r, offset_c);

        std.mem.swap(render.ScreenBuff, &prev_buff, &curr_buff);

        frameCap(io, frame_start);
    }
}

fn resetToStartScreen(prev: *render.ScreenBuff, curr: *render.ScreenBuff, writer: *Io.Writer, r_offset: usize, c_offset: usize) !void {
    curr.clear();
    _ = try curr.loadString(constants.start_screen);
    try render.renderBuff(curr, writer, r_offset, c_offset);
    @memcpy(prev.data, curr.data);
}

fn frameCap(io: std.Io, frame_start: anytype) void {
    const elapsed = std.Io.Timestamp.now(io, .real).toNanoseconds() - frame_start;
    if (elapsed < constants.dt_ns) {
        io.sleep(std.Io.Duration.fromNanoseconds(constants.dt_ns - elapsed), .awake) catch {};
    }
}
