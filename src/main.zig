const std = @import("std");
const Io = std.Io;

const terminal = @import("terminal.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const original = try terminal.enableRawMode();
    defer terminal.disableRawMode(original) catch {};

    try terminal.printANSICode(stdout_writer, terminal.ANSI_Code.enter_alternate_buffer);
    defer terminal.printANSICode(stdout_writer, terminal.ANSI_Code.exit_alternate_buffer) catch {};

    try terminal.handleInput(stdout_writer);
}
