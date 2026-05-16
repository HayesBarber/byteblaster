const std = @import("std");
const Io = std.Io;

const terminal = @import("terminal.zig");

const dt_ns = 16_666_667;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const original = try terminal.enableRawMode();
    defer terminal.disableRawMode(original) catch {};

    try terminal.printANSICode(stdout_writer, terminal.ANSICode.enter_alternate_buffer);
    defer terminal.printANSICode(stdout_writer, terminal.ANSICode.exit_alternate_buffer) catch {};

    const size = terminal.getSize();

    if (size.failed > 0) {
        try stdout_writer.writeAll("Failed to get terminal window size\n");
        std.process.exit(1);
    }

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
