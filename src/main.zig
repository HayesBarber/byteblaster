const std = @import("std");
const Io = std.Io;

const terminal = @import("terminal.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try terminal.printANSIICode(stdout_writer, terminal.ANSII_Code.enter_alternate_buffer);
    io.sleep(std.Io.Duration.fromSeconds(1), .awake) catch return;
    try terminal.printANSIICode(stdout_writer, terminal.ANSII_Code.exit_alternate_buffer);
}
