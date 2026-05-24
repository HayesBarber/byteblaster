const std = @import("std");
const testing = std.testing;
const terminal = @import("terminal.zig");
const printANSI = terminal.printANSI;

pub fn dimensions(comptime s: []const u8) struct { rows: usize, cols: usize } {
    comptime {
        var rows: usize = 0;
        var cols: usize = 0;
        var max_cols: usize = 0;

        var i: usize = 0;

        @setEvalBranchQuota(s.len * 4);
        while (i < s.len) {
            const len = std.unicode.utf8ByteSequenceLength(s[i]) catch unreachable;

            const cp = std.unicode.utf8Decode(
                s[i .. i + len],
            ) catch unreachable;

            switch (cp) {
                '\n' => {
                    rows += 1;
                    if (cols > max_cols)
                        max_cols = cols;
                    cols = 0;
                },
                else => cols += 1,
            }

            i += len;
        }

        if (cols > 0 or s.len == 0) {
            rows += 1;

            if (cols > max_cols)
                max_cols = cols;
        }

        return .{
            .rows = rows,
            .cols = max_cols,
        };
    }
}

pub fn renderComptimeArt(
    comptime s: []const u8,
    writer: *std.Io.Writer,
    r_offset: usize,
    c_offset: usize,
) !void {
    var view = try std.unicode.Utf8View.init(s);
    var iter = view.iterator();

    var r = r_offset;
    var c = c_offset;

    while (iter.nextCodepointSlice()) |cp| {
        if (std.mem.eql(u8, cp, "\n")) {
            r += 1;
            c = c_offset;
            continue;
        }

        try printANSI(writer, terminal.ANSICode.move_cursor, .{ r + 1, c + 1 });
        try writer.writeAll(cp);

        c += 1;
    }

    try writer.flush();
}

pub fn progressBarStr(
    buf: []u8,
    curr: usize,
    max: usize,
) []u8 {
    var pos: usize = 0;

    for (0..max) |i| {
        const ch = if (i < curr) "▰" else "▱";
        // unicode chars we are using for progress bar are 3 bytes
        @memcpy(buf[pos .. pos + 3], ch);
        pos += 3;
    }

    return buf[0..pos];
}

test "progressBarStr" {
    var buf: [15]u8 = undefined; // 5 visible chars

    try std.testing.expectEqualStrings(
        "▰▰▱▱▱",
        progressBarStr(&buf, 2, 5),
    );

    try std.testing.expectEqualStrings(
        "▰▰▰▰▰",
        progressBarStr(&buf, 5, 5),
    );

    try std.testing.expectEqualStrings(
        "▱▱▱▱▱",
        progressBarStr(&buf, 0, 5),
    );
}

test "single line" {
    const dims = comptime dimensions("hello");

    try testing.expectEqual(@as(usize, 1), dims.rows);
    try testing.expectEqual(@as(usize, 5), dims.cols);
}

test "multiple lines" {
    const dims = comptime dimensions(
        \\abc
        \\de
        \\fghi
    );

    try testing.expectEqual(@as(usize, 3), dims.rows);
    try testing.expectEqual(@as(usize, 4), dims.cols);
}

test "trailing newline" {
    const dims = comptime dimensions("abc\n");

    try testing.expectEqual(@as(usize, 1), dims.rows);
    try testing.expectEqual(@as(usize, 3), dims.cols);
}

test "empty string" {
    const dims = comptime dimensions("");

    try testing.expectEqual(@as(usize, 1), dims.rows);
    try testing.expectEqual(@as(usize, 0), dims.cols);
}

test "all empty lines" {
    const dims = comptime dimensions("\n\n\n");

    try testing.expectEqual(@as(usize, 3), dims.rows);
    try testing.expectEqual(@as(usize, 0), dims.cols);
}

test "ragged lines" {
    const dims = comptime dimensions(
        \\#
        \\#######
        \\###
    );

    try testing.expectEqual(@as(usize, 3), dims.rows);
    try testing.expectEqual(@as(usize, 7), dims.cols);
}
