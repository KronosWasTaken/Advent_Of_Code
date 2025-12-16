const std = @import("std");
const Result = struct { p1: []const u8, p2: []const u8 };
pub fn main() !void {
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
    std.debug.print("Part 1: {s} | Part 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
    allocator.free(result.p1);
    allocator.free(result.p2);
}
fn solve(allocator: std.mem.Allocator, input: []const u8) !Result {
    var instructions = try std.ArrayList([]const u8).initCapacity(allocator, 32);
    defer instructions.deinit(allocator);
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        try instructions.append(allocator, std.mem.trimRight(u8, line, "\r"));
    }
    var pwd1: [8]u8 = "abcdefgh".*;
    for (instructions.items) |inst| {
        try execute(&pwd1, inst);
    }
    var pwd2: [8]u8 = "fbgdceah".*;
    var i: usize = instructions.items.len;
    while (i > 0) {
        i -= 1;
        try reverse(&pwd2, instructions.items[i]);
    }
    return .{
        .p1 = try allocator.dupe(u8, &pwd1),
        .p2 = try allocator.dupe(u8, &pwd2)
    };
}
fn execute(pwd: []u8, inst: []const u8) !void {
    var it = std.mem.tokenizeScalar(u8, inst, ' ');
    const cmd = it.next().?;
    if (std.mem.eql(u8, cmd, "swap")) {
        const typ = it.next().?;
        if (std.mem.eql(u8, typ, "position")) {
            const x = try std.fmt.parseInt(usize, it.next().?, 10);
            _ = it.next();
            _ = it.next();
            const y = try std.fmt.parseInt(usize, it.next().?, 10);
            std.mem.swap(u8, &pwd[x], &pwd[y]);
        } else {
            const x = it.next().?[0];
            _ = it.next();
            _ = it.next();
            const y = it.next().?[0];
            const xi = std.mem.indexOfScalar(u8, pwd, x).?;
            const yi = std.mem.indexOfScalar(u8, pwd, y).?;
            std.mem.swap(u8, &pwd[xi], &pwd[yi]);
        }
    } else if (std.mem.eql(u8, cmd, "rotate")) {
        const dir = it.next().?;
        if (std.mem.eql(u8, dir, "based")) {
            _ = it.next();
            _ = it.next();
            _ = it.next();
            _ = it.next();
            const x = it.next().?[0];
            const idx = std.mem.indexOfScalar(u8, pwd, x).?;
            const steps = (1 + idx + @as(usize, if (idx >= 4) 1 else 0)) % pwd.len;
            rotateRight(pwd, steps);
        } else {
            const steps = try std.fmt.parseInt(usize, it.next().?, 10);
            if (std.mem.eql(u8, dir, "left")) {
                rotateLeft(pwd, steps);
            } else {
                rotateRight(pwd, steps);
            }
        }
    } else if (std.mem.eql(u8, cmd, "reverse")) {
        _ = it.next();
        const x = try std.fmt.parseInt(usize, it.next().?, 10);
        _ = it.next();
        const y = try std.fmt.parseInt(usize, it.next().?, 10);
        std.mem.reverse(u8, pwd[x..y+1]);
    } else if (std.mem.eql(u8, cmd, "move")) {
        _ = it.next();
        const x = try std.fmt.parseInt(usize, it.next().?, 10);
        _ = it.next();
        _ = it.next();
        const y = try std.fmt.parseInt(usize, it.next().?, 10);
        const ch = pwd[x];
        if (x < y) {
            std.mem.copyForwards(u8, pwd[x..y], pwd[x+1..y+1]);
        } else {
            std.mem.copyBackwards(u8, pwd[y+1..x+1], pwd[y..x]);
        }
        pwd[y] = ch;
    }
}
fn reverse(pwd: []u8, inst: []const u8) !void {
    var it = std.mem.tokenizeScalar(u8, inst, ' ');
    const cmd = it.next().?;
    if (std.mem.eql(u8, cmd, "swap")) {
        try execute(pwd, inst);
    } else if (std.mem.eql(u8, cmd, "rotate")) {
        const dir = it.next().?;
        if (std.mem.eql(u8, dir, "based")) {
            _ = it.next();
            _ = it.next();
            _ = it.next();
            _ = it.next();
            const x = it.next().?[0];

            for (0..pwd.len) |i| {
                var temp: [8]u8 = undefined;
                @memcpy(&temp, pwd);
                rotateLeft(&temp, i);
                const idx = std.mem.indexOfScalar(u8, &temp, x).?;
                const steps = (1 + idx + @as(usize, if (idx >= 4) 1 else 0)) % temp.len;
                if (steps == i) {
                    rotateLeft(pwd, i);
                    break;
                }
            }
        } else {
            const steps = try std.fmt.parseInt(usize, it.next().?, 10);
            if (std.mem.eql(u8, dir, "left")) {
                rotateRight(pwd, steps);
            } else {
                rotateLeft(pwd, steps);
            }
        }
    } else if (std.mem.eql(u8, cmd, "reverse")) {
        try execute(pwd, inst);
    } else if (std.mem.eql(u8, cmd, "move")) {
        _ = it.next();
        const x = try std.fmt.parseInt(usize, it.next().?, 10);
        _ = it.next();
        _ = it.next();
        const y = try std.fmt.parseInt(usize, it.next().?, 10);
        const ch = pwd[y];
        if (y < x) {
            std.mem.copyForwards(u8, pwd[y..x], pwd[y+1..x+1]);
        } else {
            std.mem.copyBackwards(u8, pwd[x+1..y+1], pwd[x..y]);
        }
        pwd[x] = ch;
    }
}
fn rotateLeft(pwd: []u8, steps: usize) void {
    const n = steps % pwd.len;
    std.mem.reverse(u8, pwd[0..n]);
    std.mem.reverse(u8, pwd[n..]);
    std.mem.reverse(u8, pwd);
}
fn rotateRight(pwd: []u8, steps: usize) void {
    const n = steps % pwd.len;
    std.mem.reverse(u8, pwd);
    std.mem.reverse(u8, pwd[0..n]);
    std.mem.reverse(u8, pwd[n..]);
}
