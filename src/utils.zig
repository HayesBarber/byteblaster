const std = @import("std");
const testing = std.testing;

pub fn dimensions(comptime s: []const u8) struct { rows: usize, cols: usize } {
    comptime {
        var rows: usize = 0;
        var cols: usize = 0;
        var max_cols: usize = 0;

        for (s) |c| {
            switch (c) {
                '\n' => {
                    rows += 1;
                    if (cols > max_cols) max_cols = cols;
                    cols = 0;
                },
                else => cols += 1,
            }
        }

        if (cols > 0 or s.len == 0) {
            rows += 1;
            if (cols > max_cols) max_cols = cols;
        }

        return .{
            .rows = rows,
            .cols = max_cols,
        };
    }
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
