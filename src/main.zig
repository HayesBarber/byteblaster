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

    var guard = try terminal.TerminalGuard.init(writer);
    defer guard.deinit();

    const frame_offset = try printGameFrame(allocator, writer, winsize);
    const offset_r = frame_offset.row + 1;
    const offset_c = frame_offset.col + 1;

    var prev_buff: render.ScreenBuff = try .init(allocator, constants.GAME_ROWS, constants.GAME_COLS, writer, offset_r, offset_c);
    defer prev_buff.deinit(allocator);
    var curr_buff: render.ScreenBuff = try .init(allocator, constants.GAME_ROWS, constants.GAME_COLS, writer, offset_r, offset_c);
    defer curr_buff.deinit(allocator);

    try resetToStartScreen(&prev_buff, &curr_buff);
    try writer.flush();

    var game_state = game.GameState.init(&io);

    var stats_buff = try createStatsBuffer(allocator, writer, frame_offset);
    defer stats_buff.deinit(allocator);

    var stats_str_buf: [constants.STATS.len * 2]u8 = undefined;
    _ = try stats_buff.loadString(try game_state.scoreStr(&stats_str_buf));
    try stats_buff.render();
    try writer.flush();

    while (true) {
        const frame_start = std.Io.Timestamp.now(io, .real).toNanoseconds();

        const input = terminal.pollInput() catch break;
        if (input == .esc) break;

        if (game_state.tick(&curr_buff, input)) {
            try resetToStartScreen(&prev_buff, &curr_buff);
            try writer.flush();
            game_state = game.GameState.init(&io);
        }

        if (game_state.mode == .playing) {
            try curr_buff.renderDiff(&prev_buff);
            try writer.flush();

            _ = try stats_buff.loadString(try game_state.scoreStr(&stats_str_buf));
            try stats_buff.render();
            try writer.flush();
        }

        std.mem.swap(render.ScreenBuff, &prev_buff, &curr_buff);

        if (game_state.mode == .playing) {
            curr_buff.clear();
        }

        frameCap(io, frame_start);
    }
}

fn resetToStartScreen(prev: *render.ScreenBuff, curr: *render.ScreenBuff) !void {
    curr.clear();
    _ = try curr.loadString(constants.START_SCREEN);
    try curr.render();
    @memcpy(prev.data, curr.data);
}

fn frameCap(io: std.Io, frame_start: anytype) void {
    const elapsed = std.Io.Timestamp.now(io, .real).toNanoseconds() - frame_start;
    if (elapsed < constants.DT_NS) {
        io.sleep(std.Io.Duration.fromNanoseconds(constants.DT_NS - elapsed), .awake) catch {};
    }
}

fn printGameFrame(allocator: std.mem.Allocator, writer: *Io.Writer, winsize: terminal.WinSize) !game.Point {
    const row_offset = (winsize.rows - constants.FRAME_ROWS) / 2;
    const col_offset = (winsize.cols - constants.FRAME_COLS) / 2;

    var frame_buff: render.ScreenBuff = try .init(allocator, constants.FRAME_ROWS, constants.FRAME_COLS, writer, row_offset, col_offset);
    defer frame_buff.deinit(allocator);
    const game_offset = try frame_buff.loadString(constants.GAME_FRAME);
    try frame_buff.render();
    try writer.flush();

    return game_offset;
}

fn createStatsBuffer(allocator: std.mem.Allocator, writer: *Io.Writer, game_offset: game.Point) !render.ScreenBuff {
    var stats_buff: render.ScreenBuff = try .init(
        allocator,
        constants.STATS_FRAME_ROWS,
        constants.STATS_FRAME_COLS,
        writer,
        game_offset.row,
        game_offset.col + constants.GAME_COLS + 2,
    );
    _ = try stats_buff.loadString(constants.STATS_FRAME);
    try stats_buff.render();
    try writer.flush();

    return stats_buff;
}
