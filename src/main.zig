const std = @import("std");
const Io = std.Io;

const terminal = @import("terminal.zig");
const render = @import("render.zig");

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
    defer terminal.printANSICode(stdout_writer, terminal.ANSICode.show_cursor) catch {};
    try terminal.printANSICode(stdout_writer, terminal.ANSICode.enter_alternate_buffer);
    defer terminal.printANSICode(stdout_writer, terminal.ANSICode.exit_alternate_buffer) catch {};

    const allocator = init.gpa;

    var prev_buff: render.ScreenBuff = try .init(allocator, size.rows, size.cols);
    defer prev_buff.deinit(allocator);

    var curr_buff: render.ScreenBuff = try .init(allocator, size.rows, size.cols);
    defer curr_buff.deinit(allocator);

    try curr_buff.loadString(start_screen);
    try render.renderBuff(&prev_buff, &curr_buff, stdout_writer);

    game_loop: while (true) {
        const input = terminal.pollInput() catch break :game_loop;

        switch (input) {
            .j => {},
            .k => {},
            .esc => break :game_loop,
            else => {},
        }

        // update();
        // render();

        io.sleep(std.Io.Duration.fromNanoseconds(dt_ns), .awake) catch {};
    }
}
