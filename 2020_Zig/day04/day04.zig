const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn encode3(s: []const u8) u32 {
    return (@as(u32, s[0]) << 16) | (@as(u32, s[1]) << 8) | s[2];
}

fn checkRange(value: []const u8, digits: usize, min: usize, max: usize) bool {
    if (value.len != digits) return false;
    var n: usize = 0;
    for (value) |c| {
        if (c < '0' or c > '9') return false;
        n = n * 10 + (c - '0');
    }
    return n >= min and n <= max;
}

fn checkHex(value: []const u8, digits: usize) bool {
    if (value.len != digits + 1 or value[0] != '#') return false;
    for (value[1..]) |c| {
        if (!std.ascii.isHex(c)) return false;
    }
    return true;
}

fn checkEyeColor(value: []const u8) bool {
    if (value.len != 3) return false;
    return switch (encode3(value)) {
        encode3("amb"), encode3("blu"), encode3("brn"), encode3("gry"), encode3("grn"), encode3("hzl"), encode3("oth") => true,
        else => false,
    };
}

fn checkHeight(value: []const u8) bool {
    if (value.len < 4) return false;
    const unit = value[value.len - 2 ..];
    if (std.mem.eql(u8, unit, "cm")) {
        return checkRange(value[0 .. value.len - 2], 3, 150, 193);
    }
    if (std.mem.eql(u8, unit, "in")) {
        return checkRange(value[0 .. value.len - 2], 2, 59, 76);
    }
    return false;
}

fn validateField(key: []const u8, value: []const u8) bool {
    const tag = encode3(key);
    return switch (tag) {
        encode3("byr") => checkRange(value, 4, 1920, 2002),
        encode3("iyr") => checkRange(value, 4, 2010, 2020),
        encode3("eyr") => checkRange(value, 4, 2020, 2030),
        encode3("pid") => checkRange(value, 9, 0, 999999999),
        encode3("hcl") => checkHex(value, 6),
        encode3("ecl") => checkEyeColor(value),
        encode3("hgt") => checkHeight(value),
        encode3("cid") => true,
        else => false,
    };
}

fn solve(input: []const u8) Result {
    var part1: usize = 0;
    var part2: usize = 0;

    var i: usize = 0;
    while (i < input.len) {
        var have: u8 = 0;
        var bad = false;

        while (i < input.len) {
            if (input[i] == '\n' or input[i] == '\r') {
                const first = input[i];
                i += 1;
                if (first == '\r' and i < input.len and input[i] == '\n') i += 1;

                if (i < input.len and (input[i] == '\n' or input[i] == '\r')) {
                    if (input[i] == '\r') i += 1;
                    if (i < input.len and input[i] == '\n') i += 1;
                    break;
                }
                continue;
            }

            if (i + 3 > input.len) break;
            const key = input[i .. i + 3];
            i += 3;
            if (i >= input.len or input[i] != ':') break;
            i += 1;
            const value_start = i;
            while (i < input.len and input[i] != ' ' and input[i] != '\n' and input[i] != '\r') : (i += 1) {}
            const value = input[value_start..i];

            const is_valid = validateField(key, value);
            if (!std.mem.eql(u8, key, "cid")) {
                have |= @as(u8, 1) << @intCast((encode3(key) % 477) % 8);
                bad = bad or !is_valid;
            }

            if (i < input.len and input[i] == ' ') i += 1;
        }

        const complete = (have | (@as(u8, 1) << @intCast((encode3("cid") % 477) % 8))) == 0xff;
        part1 += @intFromBool(complete);
        part2 += @intFromBool(complete and !bad);
    }

    return .{ .p1 = part1, .p2 = part2 };
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
