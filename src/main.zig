const std = @import("std");
const Io = std.Io;

const terminal = @import("terminal.zig");

const dt_ns = 16_666_667;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &.{});
    const stdout_writer = &stdout_file_writer.interface;

    const size = terminal.getSize() catch |e| {
        switch (e) {
            error.FailedToGetSize => try stdout_writer.print("Failed to get terminal window size\n", .{}),
            error.TooFewColumns => try stdout_writer.print("Terminal columns needs to be at least 128\n", .{}),
            error.TooFewRows => try stdout_writer.print("Terminal rows needs to be at least 32\n", .{}),
        }
        return;
    };

    try stdout_writer.print("Rows: {d}, Cols: {d}", .{ size.rows, size.cols });

    const original = try terminal.enableRawMode();
    defer terminal.disableRawMode(original) catch {};

    try terminal.printANSICode(stdout_writer, terminal.ANSICode.enter_alternate_buffer);
    defer terminal.printANSICode(stdout_writer, terminal.ANSICode.exit_alternate_buffer) catch {};

    game_loop: while (true) {
        const input = terminal.pollInput() catch break :game_loop;

        switch (input) {
            .j => {
                try stdout_writer.print("j", .{});
                try stdout_writer.flush();
            },
            .k => {
                try stdout_writer.print("k", .{});
                try stdout_writer.flush();
            },
            .esc => break :game_loop,
            else => {},
        }

        // update();
        // render();

        io.sleep(std.Io.Duration.fromNanoseconds(dt_ns), .awake) catch {};
    }
}
