const std = @import("std");
const Io = std.Io;

const terminal = @import("terminal.zig");
const render = @import("render.zig");
const game = @import("game.zig");
const constants = @import("constants.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    var stdout_buf: [constants.STDOUT_BUFFER_SIZE]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buf);
    const writer = &stdout_file_writer.interface;

    const winsize = terminal.getSize() catch |e| {
        const msg = switch (e) {
            error.FailedToGetSize => "Failed to get terminal window size\n",
            error.TooFewColumns => "Too few terminal columns\n",
            error.TooFewRows => "Too few terminal rows\n",
        };
        try writer.writeAll(msg);
        return;
    };
    const row_offset = (winsize.rows - constants.FRAME_ROWS) / 2;
    const col_offset = (winsize.cols - constants.FRAME_COLS) / 2;

    var guard = try terminal.TerminalGuard.init(writer);
    defer guard.deinit();

    var game_buff: render.ScreenBuff = try .init(
        allocator,
        writer,
        row_offset,
        col_offset,
        constants.GAME_FRAME,
    );
    defer game_buff.deinit(allocator);
    try game_buff.loadString(constants.START_SCREEN);
    try game_buff.renderDiff();

    var game_state = game.GameState.init(&io);

    var stats_buff: render.ScreenBuff = try .init(
        allocator,
        writer,
        row_offset,
        col_offset + constants.FRAME_COLS,
        constants.STATS_FRAME,
    );
    defer stats_buff.deinit(allocator);
    var stats_str_buf: [constants.STATS.len * 2]u8 = undefined;
    try stats_buff.loadString(try game_state.scoreStr(&stats_str_buf));
    try stats_buff.renderDiff();

    while (true) {
        const frame_start = std.Io.Timestamp.now(io, .real).toNanoseconds();

        const input = terminal.pollInput() catch break;
        if (input == .esc) break;

        if (game_state.tick(&game_buff, input)) {
            try game_buff.loadString(constants.START_SCREEN);
            try game_buff.renderDiff();
            game_state = game.GameState.init(&io);
        }

        if (game_state.mode == .playing) {
            try game_buff.renderDiff();
            try stats_buff.loadString(try game_state.scoreStr(&stats_str_buf));
            try stats_buff.renderDiff();
        }

        frameCap(io, frame_start);
    }
}

fn frameCap(io: std.Io, frame_start: anytype) void {
    const elapsed = std.Io.Timestamp.now(io, .real).toNanoseconds() - frame_start;
    if (elapsed < constants.DT_NS) {
        io.sleep(std.Io.Duration.fromNanoseconds(constants.DT_NS - elapsed), .awake) catch {};
    }
}
