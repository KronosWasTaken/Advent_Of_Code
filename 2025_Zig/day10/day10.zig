const std = @import("std");

const Result = struct { p1: i32, p2: i32 };

pub fn solve(input: []const u8) Result {
    var p1: i32 = 0;
    var p2: i32 = 0;

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line_raw| {
        if (line_raw.len == 0) continue;
        const line = std.mem.trim(u8, line_raw, "\r");
        if (line.len == 0) continue;

        const parsed = parseLine(line);
        p1 += parsed.part1;
        p2 += parsed.part2;
    }

    return .{ .p1 = p1, .p2 = p2 };
}

const ParsedLine = struct { part1: i32, part2: i32 };

fn parseLine(line: []const u8) ParsedLine {
    const lights_section = line[1..];
    const split1 = std.mem.indexOf(u8, lights_section, "] (") orelse unreachable;
    const lights_str = lights_section[0..split1];
    const rest1 = lights_section[split1 + 3 ..];

    const split2 = std.mem.indexOf(u8, rest1, ") {") orelse unreachable;
    const buttons_str = rest1[0..split2];
    const joltages_str = rest1[split2 + 3 .. rest1.len - 1];

    const lights_mask = parseLights(lights_str);
    const buttons = parseButtons(buttons_str);
    const joltages = parseJoltages(joltages_str);
    defer std.heap.page_allocator.free(buttons);
    defer std.heap.page_allocator.free(joltages);

    return .{
        .part1 = configureLights(lights_mask, buttons),
        .part2 = configureJoltages(buttons, joltages),
    };
}

fn parseLights(lights_str: []const u8) u16 {
    var mask: u16 = 0;
    var i: usize = 0;
    while (i < lights_str.len) : (i += 1) {
        if (lights_str[i] == '#') mask |= (@as(u16, 1) << @intCast(i));
    }
    return mask;
}

fn parseButtons(buttons_str: []const u8) []u16 {
    const allocator = std.heap.page_allocator;
    var buttons = std.ArrayListUnmanaged(u16){};

    var iter = std.mem.splitSequence(u8, buttons_str, ") (");
    while (iter.next()) |button_str| {
        var mask: u16 = 0;
        var nums = std.mem.tokenizeScalar(u8, button_str, ',');
        while (nums.next()) |num| {
            if (num.len == 0) continue;
            const value = std.fmt.parseInt(u16, num, 10) catch continue;
            mask |= (@as(u16, 1) << @intCast(value));
        }
        buttons.append(allocator, mask) catch unreachable;
    }

    return buttons.toOwnedSlice(allocator) catch unreachable;
}

fn parseJoltages(joltages_str: []const u8) []i32 {
    const allocator = std.heap.page_allocator;
    var joltages = std.ArrayListUnmanaged(i32){};

    var nums = std.mem.tokenizeScalar(u8, joltages_str, ',');
    while (nums.next()) |num| {
        if (num.len == 0) continue;
        const value = std.fmt.parseInt(i32, num, 10) catch continue;
        joltages.append(allocator, value) catch unreachable;
    }

    return joltages.toOwnedSlice(allocator) catch unreachable;
}

fn configureLights(lights: u16, buttons: []const u16) i32 {
    const limit: u32 = @as(u32, 1) << @intCast(buttons.len);
    var set: u32 = 0;

    while (true) {
        set += 1;
        var mask: u32 = (@as(u32, 1) << @intCast(set)) - 1;
        while (mask < limit) {
            var acc: u16 = 0;
            var temp = mask;
            while (temp != 0) {
                const bit = @ctz(temp);
                acc ^= buttons[@intCast(bit)];
                temp &= temp - 1;
            }
            if (acc == lights) return @intCast(set);
            mask = nextSameBits(mask);
        }
    }
}

fn nextSameBits(n: u32) u32 {
    const smallest = n & (~n + 1);
    const ripple = n + smallest;
    const ones = n ^ ripple;
    const next = (ones >> 2) / smallest;
    return ripple | next;
}

fn configureJoltages(buttons: []const u16, joltages: []const i32) i32 {
    const cols = buttons.len + 1;
    const rows = joltages.len;

    var matrix = std.heap.page_allocator.alloc(i32, cols * rows) catch unreachable;
    defer std.heap.page_allocator.free(matrix);
    @memset(matrix, 0);

    var i: usize = 0;
    while (i < buttons.len) : (i += 1) {
        var button = buttons[i];
        while (button != 0) {
            const bit = @ctz(button);
            matrix[bit * cols + i] = 1;
            button &= button - 1;
        }
    }

    var r: usize = 0;
    while (r < rows) : (r += 1) {
        matrix[r * cols + (cols - 1)] = joltages[r];
    }

    var pivot: usize = 0;
    var c: usize = 0;
    while (c + 1 < cols) : (c += 1) {
        var row = pivot;
        while (row < rows and matrix[row * cols + c] == 0) : (row += 1) {}
        if (row >= rows) continue;

        if (pivot != row) {
            var k: usize = 0;
            while (k < cols) : (k += 1) {
                const a = pivot * cols + k;
                const b = row * cols + k;
                const tmp = matrix[a];
                matrix[a] = matrix[b];
                matrix[b] = tmp;
            }
        }

        if (pivot != c) {
            var r2: usize = 0;
            while (r2 < rows) : (r2 += 1) {
                const a = r2 * cols + c;
                const b = r2 * cols + pivot;
                const tmp = matrix[a];
                matrix[a] = matrix[b];
                matrix[b] = tmp;
            }
        }

        const pivot_val = matrix[pivot * cols + pivot];
        var r3: usize = 0;
        while (r3 < rows) : (r3 += 1) {
            if (r3 == pivot) continue;
            const factor = matrix[r3 * cols + pivot];
            if (factor != 0) {
                var k2: usize = 0;
                while (k2 < cols) : (k2 += 1) {
                    matrix[r3 * cols + k2] *= pivot_val;
                    matrix[r3 * cols + k2] -= matrix[pivot * cols + k2] * factor;
                }
            }
        }

        pivot += 1;
        if (pivot >= rows) break;
    }

    var max_value: i32 = 0;
    for (joltages) |j| {
        if (j > max_value) max_value = j;
    }

    var vars = std.ArrayListUnmanaged(usize){};
    defer vars.deinit(std.heap.page_allocator);

    var loop_idx: usize = pivot;
    while (loop_idx < cols - 1) : (loop_idx += 1) {
        var chosen: ?usize = null;
        var row_idx: usize = 0;
        while (row_idx < rows) : (row_idx += 1) {
            var k: usize = 0;
            var candidate: usize = 0;
            var c2: usize = pivot;
            while (c2 < cols - 1) : (c2 += 1) {
                if (matrix[row_idx * cols + c2] != 0 and !contains(vars.items, c2)) {
                    if (k != 0) {
                        candidate = 0;
                        break;
                    }
                    candidate = c2;
                    k = 1;
                }
            }
            if (candidate != 0) {
                chosen = candidate;
                break;
            }
        }

        if (chosen == null) {
            var best_c = pivot;
            var best_count: usize = 0;
            var c3: usize = pivot;
            while (c3 < cols - 1) : (c3 += 1) {
                if (contains(vars.items, c3)) continue;
                var count: usize = 0;
                var r4: usize = 0;
                while (r4 < rows) : (r4 += 1) {
                    if (matrix[r4 * cols + c3] != 0) count += 1;
                }
                if (count > best_count) {
                    best_count = count;
                    best_c = c3;
                }
            }
            chosen = best_c;
        }

        vars.append(std.heap.page_allocator, chosen.?) catch unreachable;
    }

    const values = std.heap.page_allocator.alloc(i32, vars.items.len) catch unreachable;
    defer std.heap.page_allocator.free(values);
    @memset(values, 0);

    return solveRec(vars.items, values, matrix, cols, rows, max_value, 0) catch unreachable;
}

fn contains(slice: []const usize, value: usize) bool {
    for (slice) |v| if (v == value) return true;
    return false;
}

fn solveRec(
    vars: []const usize,
    values: []i32,
    matrix: []const i32,
    cols: usize,
    rows: usize,
    max_value: i32,
    best: i32,
) !i32 {
    if (vars.len == 0) {
        var tot: i32 = 0;
        for (values) |v| tot += v;
        var r: usize = 0;
        while (r < cols - 1 - values.len) : (r += 1) {
            var sum = matrix[r * cols + (cols - 1)];
            var i: usize = 0;
            while (i < values.len) : (i += 1) {
                const c = cols - 1 - values.len + i;
                sum -= matrix[r * cols + c] * values[i];
            }
            if (@rem(sum, matrix[r * cols + r]) != 0) return best;
            sum = @divTrunc(sum, matrix[r * cols + r]);
            if (sum < 0) return best;
            tot += sum;
        }
        return if (best == 0 or tot < best) tot else best;
    }

    const x = vars[0];
    var min: i32 = 0;
    var max: i32 = max_value;

    var r2: usize = 0;
    while (r2 < rows) : (r2 += 1) {
        if (matrix[r2 * cols + x] == 0) continue;
        var n = matrix[r2 * cols + r2];
        const m = matrix[r2 * cols + x];
        var rhs = matrix[r2 * cols + (cols - 1)];

        var i: usize = 0;
        while (i < values.len) : (i += 1) {
            const c = cols - 1 - values.len + i;
            if (c != x and matrix[r2 * cols + c] != 0) {
                if (contains(vars, c)) {
                    if ((matrix[r2 * cols + c] > 0) == (n > 0)) {
                        n += matrix[r2 * cols + c];
                    } else {
                        n = 0;
                        break;
                    }
                } else {
                    rhs -= matrix[r2 * cols + c] * values[i];
                }
            }
        }
        if (n == 0) continue;

        if ((n > 0) != (m > 0)) {
            min = @max(min, @divTrunc(rhs, m));
            max = @min(max, @divTrunc(rhs - max_value * n, m));
        } else {
            max = @min(max, @divTrunc(rhs, m));
            min = @max(min, @divTrunc(rhs - max_value * n + (m - 1), m));
        }
    }

    var v: i32 = min;
    var best_val: i32 = if (best == 0) std.math.maxInt(i32) else best;
    while (v <= max) : (v += 1) {
        values[x - (cols - 1 - values.len)] = v;
        const candidate = try solveRec(vars[1..], values, matrix, cols, rows, max_value, best_val);
        if (candidate < best_val) best_val = candidate;
        max = @min(max, best_val);
    }

    return best_val;
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
