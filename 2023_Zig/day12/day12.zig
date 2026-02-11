const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const MAX_PATTERN = 200;
const MAX_GROUPS = 50;
const MAX_TABLE = MAX_PATTERN * MAX_GROUPS;

fn solveFor(input: []const u8, repeat: u8) u64 {
    @setRuntimeSafety(false);
    var result: u64 = 0;

    var pattern_buf: [MAX_PATTERN]u8 = undefined;
    var groups_buf: [MAX_GROUPS]u8 = undefined;
    var broken: [MAX_PATTERN + 1]u16 = undefined;
    var table: [MAX_TABLE]u64 = undefined;

    var idx: usize = 0;
    while (idx < input.len) {
        if (input[idx] == '\r' or input[idx] == '\n') {
            idx += 1;
            continue;
        }
        const line_start = idx;
        while (idx < input.len and input[idx] != '\n') : (idx += 1) {}
        const line = std.mem.trimRight(u8, input[line_start..idx], "\r");
        if (line.len == 0) continue;
        const space = std.mem.indexOfScalar(u8, line, ' ') orelse continue;
        const pattern = line[0..space];
        const groups_str = line[space + 1 ..];

        var groups_len: usize = 0;
        var groups_sum: usize = 0;
        var gidx: usize = 0;
        while (gidx < groups_str.len) {
            while (gidx < groups_str.len and (groups_str[gidx] < '0' or groups_str[gidx] > '9')) : (gidx += 1) {}
            if (gidx >= groups_str.len) break;
            var value: u8 = 0;
            while (gidx < groups_str.len and groups_str[gidx] >= '0' and groups_str[gidx] <= '9') : (gidx += 1) {
                value = value * 10 + (groups_str[gidx] - '0');
            }
            groups_buf[groups_len] = value;
            groups_len += 1;
            groups_sum += value;
        }

        var pat_len: usize = 0;
        var r: u8 = 0;
        while (r < repeat - 1) : (r += 1) {
            @memcpy(pattern_buf[pat_len .. pat_len + pattern.len], pattern);
            pat_len += pattern.len;
            pattern_buf[pat_len] = '?';
            pat_len += 1;
        }
        @memcpy(pattern_buf[pat_len .. pat_len + pattern.len], pattern);
        pat_len += pattern.len;
        pattern_buf[pat_len] = '.';
        pat_len += 1;

        var full_groups_len: usize = 0;
        var total_groups_sum: usize = 0;
        r = 0;
        while (r < repeat) : (r += 1) {
            @memcpy(groups_buf[full_groups_len .. full_groups_len + groups_len], groups_buf[0..groups_len]);
            full_groups_len += groups_len;
            total_groups_sum += groups_sum;
        }

        const wiggle = pat_len - total_groups_sum - full_groups_len + 1;

        var broken_sum: u16 = 0;
        broken[0] = 0;
        var i: usize = 0;
        while (i < pat_len) : (i += 1) {
            if (pattern_buf[i] != '.') broken_sum += 1;
            broken[i + 1] = broken_sum;
        }

        const rows = full_groups_len;
        const table_len = pat_len * rows;
        @memset(table[0..table_len], 0);

        const size0 = groups_buf[0];
        var sum: u64 = 0;
        var valid = true;
        const pat_ptr: [*]u8 = &pattern_buf;
        const broken_ptr: [*]u16 = &broken;
        const table_ptr: [*]u64 = &table;
        i = 0;
        while (i + 3 < wiggle) : (i += 4) {
            inline for (0..4) |k| {
                const pos = i + k;
                const end_idx = pos + size0;
                if (pat_ptr[end_idx] == '#') {
                    sum = 0;
                } else if (valid and broken_ptr[end_idx] - broken_ptr[pos] == size0) {
                    sum += 1;
                }
                table_ptr[end_idx] = sum;
                valid = valid and pat_ptr[pos] != '#';
            }
        }
        while (i < wiggle) : (i += 1) {
            const end_idx = i + size0;
            if (pat_ptr[end_idx] == '#') {
                sum = 0;
            } else if (valid and broken_ptr[end_idx] - broken_ptr[i] == size0) {
                sum += 1;
            }
            table_ptr[end_idx] = sum;
            valid = valid and pat_ptr[i] != '#';
        }

        var start = size0 + 1;
        var row: usize = 1;
        while (row < rows) : (row += 1) {
            const size = groups_buf[row];
            const previous = (row - 1) * pat_len;
            const current = row * pat_len;
            sum = 0;
            i = start;
            const end_limit = start + wiggle;
            while (i + 3 < end_limit) : (i += 4) {
                inline for (0..4) |k| {
                    const pos = i + k;
                    const end_idx = pos + size;
                    if (pat_ptr[end_idx] == '#') {
                        sum = 0;
                    } else if (table_ptr[previous + pos - 1] > 0 and pat_ptr[pos - 1] != '#' and broken_ptr[end_idx] - broken_ptr[pos] == size) {
                        sum += table_ptr[previous + pos - 1];
                    }
                    table_ptr[current + end_idx] = sum;
                }
            }
            while (i < end_limit) : (i += 1) {
                const end_idx = i + size;
                if (pat_ptr[end_idx] == '#') {
                    sum = 0;
                } else if (table_ptr[previous + i - 1] > 0 and pat_ptr[i - 1] != '#' and broken_ptr[end_idx] - broken_ptr[i] == size) {
                    sum += table_ptr[previous + i - 1];
                }
                table_ptr[current + end_idx] = sum;
            }
            start += size + 1;
        }

        result += sum;
    }

    return result;
}

pub fn solve(input: []const u8) Result {
    return .{ .p1 = solveFor(input, 1), .p2 = solveFor(input, 5) };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
