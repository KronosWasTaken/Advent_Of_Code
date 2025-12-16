const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(input);
    var timer = try std.time.Timer.start();
    const result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    var p1: u32 = 0;
    var p2: u32 = 0;
    var i: usize = 0;
    outer: while (i < input.len) {
        const line_start = i;
        while (i < input.len and input[i] != '\n' and input[i] != '\r') : (i += 1) {}
        const line = input[line_start..i];
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}
        if (line.len < 11) continue;
        const name = line[0 .. line.len - 11];
        const sector_id = parseU32(line[line.len - 10 .. line.len - 7]);
        const checksum = line[line.len - 6 .. line.len - 1];

        var freq = [_]u8{0} ** 26;
        var fof = [_]i32{0} ** 26;
        var highest: u8 = 0;
        for (name) |c| {
            if (c >= 'a' and c <= 'z') {
                const idx = c - 'a';
                const current = freq[idx];
                const next = current + 1;
                freq[idx] = next;
                fof[current] -= 1;
                fof[next] += 1;
                highest = @max(highest, next);
            }
        }

        if (freq[checksum[0] - 'a'] != highest) continue;
        for (0..4) |j| {
            const end = freq[checksum[j] - 'a'];
            const start = freq[checksum[j + 1] - 'a'];
            if (start > end or (start == end and checksum[j + 1] <= checksum[j])) {
                continue :outer;
            }
            var k = start + 1;
            while (k < end) : (k += 1) {
                if (fof[k] != 0) continue :outer;
            }
        }
        p1 += sector_id;

        if (name.len == 24 and name[9] == '-' and name[16] == '-') {
            const rotate = @as(u8, @intCast(sector_id % 26));
            const target = "northpole object storage";
            var match = true;
            for (name, 0..) |c, j| {
                const decoded = if (c == '-') ' ' else (c - 'a' + rotate) % 26 + 'a';
                if (decoded != target[j]) {
                    match = false;
                    break;
                }
            }
            if (match) p2 = sector_id;
        }
    }
    return .{ .p1 = p1, .p2 = p2 };
}
fn parseU32(s: []const u8) u32 {
    var result: u32 = 0;
    for (s) |c| {
        if (c >= '0' and c <= '9') {
            result = result * 10 + (c - '0');
        }
    }
    return result;
}
