const std = @import("std");

fn fill(pwd: *[8]u8, start: u8) void {
    pwd[3] = start;
    pwd[4] = start;
    pwd[5] = start + 1;
    pwd[6] = start + 2;
    pwd[7] = start + 2;
}

fn nextPassword(pwd: *[8]u8) void {
    if (pwd[3] >= 'g' and pwd[3] <= 'o') {
        fill(pwd, 'p');
        return;
    }
    if (pwd[3] <= 'x') {
        var cand = pwd.*;
        fill(&cand, pwd[3]);
        if (std.mem.order(u8, &cand, pwd) == .gt) {
            pwd.* = cand;
            return;
        }
    }
    if (pwd[3] == 'x') {
        pwd[2] += if (pwd[2] == 'h' or pwd[2] == 'n' or pwd[2] == 'k') 2 else 1;
        fill(pwd, 'a');
    } else if (pwd[3] == 'f') {
        fill(pwd, 'p');
    } else {
        fill(pwd, pwd[3] + 1);
    }
}

fn clean(pwd: *[8]u8) void {
    for (0..8) |i| {
        const c = pwd[i];
        if (c == 'i' or c == 'o' or c == 'l') {
            pwd[i] += 1;
            @memset(pwd[i + 1 .. 8], 'a');
            break;
        }
    }
}

fn solve(input: []const u8) struct { p1: [8]u8, p2: [8]u8 } {
    var pwd: [8]u8 = undefined;
    @memcpy(&pwd, input[0..8]);
    clean(&pwd);

    nextPassword(&pwd);
    const p1 = pwd;

    nextPassword(&pwd);
    const p2 = pwd;

    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = "hepxcrrq";
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\nPart 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
