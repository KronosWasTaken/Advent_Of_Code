const std = @import("std");

fn solve(data: []const u8) [2]u32 {
    @setRuntimeSafety(false);
    var paper: u32 = 0;
    var ribbon: u32 = 0;
    var i: usize = 0;
    
    while (i < data.len) {
        var l: u32 = data[i] - '0';
        i += 1;
        while (data[i] >= '0') {
            l = l * 10 + (data[i] - '0');
            i += 1;
        }
        i += 1;

        var w: u32 = data[i] - '0';
        i += 1;
        while (data[i] >= '0') {
            w = w * 10 + (data[i] - '0');
            i += 1;
        }
        i += 1;

        var h: u32 = data[i] - '0';
        i += 1;
        while (i < data.len and data[i] >= '0') {
            h = h * 10 + (data[i] - '0');
            i += 1;
        }
        i += 1;

        if (l > w) { const t = l; l = w; w = t; }
        if (w > h) { const t = w; w = h; h = t; }
        if (l > w) { const t = l; l = w; w = t; }

        paper += 2 * (l*w + w*h + h*l) + (l*w);
        ribbon += 2 * (l + w) + (l * w * h);
    }
    return .{ paper, ribbon };
}

pub fn main() !void {
    const data = @embedFile("input.txt");
    
    _ = solve(data);
    
    const iterations = 10000;
    var timer = try std.time.Timer.start();
    const start = timer.read();
    
    var result: [2]u32 = undefined;
    for (0..iterations) |_| {
        result = solve(data);
    }
    
    const end = timer.read();
    const elapsed_ns = end - start;
    const avg_us = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) / 1000.0;
    
    std.debug.print("Part 1: {}\n", .{result[0]});
    std.debug.print("Part 2: {}\n", .{result[1]});
    std.debug.print("Time: {d:.3} microseconds (avg of {} iterations)\n", .{avg_us, iterations});
}
