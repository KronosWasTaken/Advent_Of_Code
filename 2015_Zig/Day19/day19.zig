const std = @import("std");

const Replacement = struct {
    from: []const u8,
    to: []const u8,
};

fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var reps_buf: [64]Replacement = undefined;
    var rep_count: usize = 0;
    var molecule: []const u8 = "";

    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, " => ")) |idx| {
            reps_buf[rep_count] = .{
                .from = line[0..idx],
                .to = line[idx + 4 ..],
            };
            rep_count += 1;
        } else {
            molecule = line;
        }
    }
    const reps = reps_buf[0..rep_count];

    var set: [2048]u64 = [_]u64{0} ** 2048;
    var p1: u32 = 0;
    var buffer: [600]u8 = undefined;

    for (reps) |rep| {
        const from_len = rep.from.len;
        if (from_len > molecule.len) continue;
        const max_pos = molecule.len - from_len;
        var pos: usize = 0;
        while (pos <= max_pos) : (pos += 1) {
            if (std.mem.eql(u8, molecule[pos .. pos + from_len], rep.from)) {
                const new_len = molecule.len - from_len + rep.to.len;
                @memcpy(buffer[0..pos], molecule[0..pos]);
                @memcpy(buffer[pos .. pos + rep.to.len], rep.to);
                @memcpy(buffer[pos + rep.to.len .. new_len], molecule[pos + from_len ..]);

                var h = std.hash.Wyhash.hash(0, buffer[0..new_len]);
                if (h == 0) h = 1;
                var idx = @as(usize, @truncate(h)) & 2047;
                while (set[idx] != 0) {
                    if (set[idx] == h) break;
                    idx = (idx + 1) & 2047;
                } else {
                    set[idx] = h;
                    p1 += 1;
                }
            }
        }
    }

    var total: u32 = 0;
    var rn: u32 = 0;
    var ar: u32 = 0;
    var y: u32 = 0;

    var i: usize = 0;
    while (i < molecule.len) {
        if (i + 1 < molecule.len) {
            if (molecule[i] == 'R' and molecule[i + 1] == 'n') {
                rn += 1;
                total += 1;
                i += 2;
                continue;
            } else if (molecule[i] == 'A' and molecule[i + 1] == 'r') {
                ar += 1;
                total += 1;
                i += 2;
                continue;
            }
        }
        if (molecule[i] >= 'A' and molecule[i] <= 'Z') {
            if (molecule[i] == 'Y') y += 1;
            total += 1;
        }
        i += 1;
    }

    const p2 = total - rn - ar - 2 * y - 1;
    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
