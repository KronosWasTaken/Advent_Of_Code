const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn old_main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(input);
    var timer = try std.time.Timer.start();
    const result = try solve(allocator, input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    var discs: [8][2]u32 = undefined;
    var num_discs: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const line_start = i;
        while (i < input.len and input[i] != '\n') : (i += 1) {}
        const line = input[line_start..i];
        i += 1;
        if (line.len == 0) continue;

        var j: usize = 0;
        var nums: [4]u32 = undefined;
        var num_count: usize = 0;
        while (j < line.len and num_count < 4) {
            if (line[j] >= '0' and line[j] <= '9') {
                var n: u32 = 0;
                while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                    n = n * 10 + (line[j] - '0');
                }
                nums[num_count] = n;
                num_count += 1;
            } else {
                j += 1;
            }
        }
        if (num_count >= 4) {

discs[num_discs] = .{ nums[1], nums[3] };
            num_discs += 1;
        }
    }
    const p1 = findTime(discs[0..num_discs]);

    discs[num_discs] = .{ 11, 0 };
    const p2 = findTime(discs[0 .. num_discs + 1]);
    return .{ .p1 = p1, .p2 = p2 };
}
fn findTime(discs: [][2]u32) u32 {

    var time: u32 = 0;
    var step: u32 = 1;
    for (discs, 0..) |disc, offset| {
        const size = disc[0];
        const pos = disc[1];
        while ((time + @as(u32, @intCast(offset)) + 1 + pos) % size != 0) {
            time += step;
        }
        step *= size;
    }
    return time;
}
