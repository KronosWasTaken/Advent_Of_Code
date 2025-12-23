const std = @import("std");

const Result = struct { p1: usize, p2: usize };

fn exec(op: usize, a: usize, b: usize, c: usize, reg: *[4]usize) void {
    reg[c] = switch (op) {
        0 => reg[a] +% reg[b],
        1 => reg[a] +% b,
        2 => reg[a] *% reg[b],
        3 => reg[a] *% b,
        4 => reg[a] & reg[b],
        5 => reg[a] & b,
        6 => reg[a] | reg[b],
        7 => reg[a] | b,
        8 => reg[a],
        9 => a,
        10 => if (a > reg[b]) @as(usize, 1) else 0,
        11 => if (reg[a] > b) @as(usize, 1) else 0,
        12 => if (reg[a] > reg[b]) @as(usize, 1) else 0,
        13 => if (a == reg[b]) @as(usize, 1) else 0,
        14 => if (reg[a] == b) @as(usize, 1) else 0,
        15 => if (reg[a] == reg[b]) @as(usize, 1) else 0,
        else => unreachable,
    };
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const last_after = std.mem.lastIndexOf(u8, input, "After:") orelse return Result{ .p1 = 0, .p2 = 0 };
    const after_line_end = std.mem.indexOfScalarPos(u8, input, last_after, '\n') orelse input.len;
    
    var split_idx = after_line_end + 1;
    while (split_idx < input.len and (input[split_idx] == '\n' or input[split_idx] == '\r')) {
        split_idx += 1;
    }
    
    const samples_part = input[0..after_line_end];
    const program_part = input[split_idx..];
    
    var samples = std.ArrayList(struct { before: [4]usize, instr: [4]usize, after: [4]usize }){};
    defer samples.deinit(allocator);
    
    var lines = std.mem.splitScalar(u8, samples_part, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "Before:")) {
            var before: [4]usize = undefined;
            var i: usize = 9;
            var idx: usize = 0;
            while (i < line.len and idx < 4) {
                if (line[i] >= '0' and line[i] <= '9') {
                    var n: usize = 0;
                    while (i < line.len and line[i] >= '0' and line[i] <= '9') {
                        n = n * 10 + (line[i] - '0');
                        i += 1;
                    }
                    before[idx] = n;
                    idx += 1;
                } else {
                    i += 1;
                }
            }
            
            const instr_line = lines.next().?;
            var instr: [4]usize = undefined;
            i = 0;
            idx = 0;
            while (i < instr_line.len and idx < 4) {
                if (instr_line[i] >= '0' and instr_line[i] <= '9') {
                    var n: usize = 0;
                    while (i < instr_line.len and instr_line[i] >= '0' and instr_line[i] <= '9') {
                        n = n * 10 + (instr_line[i] - '0');
                        i += 1;
                    }
                    instr[idx] = n;
                    idx += 1;
                } else {
                    i += 1;
                }
            }
            
            const after_line = lines.next().?;
            var after: [4]usize = undefined;
            i = 9;
            idx = 0;
            while (i < after_line.len and idx < 4) {
                if (after_line[i] >= '0' and after_line[i] <= '9') {
                    var n: usize = 0;
                    while (i < after_line.len and after_line[i] >= '0' and after_line[i] <= '9') {
                        n = n * 10 + (after_line[i] - '0');
                        i += 1;
                    }
                    after[idx] = n;
                    idx += 1;
                } else {
                    i += 1;
                }
            }
            
            samples.append(allocator, .{ .before = before, .instr = instr, .after = after }) catch unreachable;
        }
    }
    
    var part1: usize = 0;
    var candidates = [_]u16{0xffff} ** 16;
    
    for (samples.items) |sample| {
        var count: usize = 0;
        var mask: u16 = 0;
        
        for (0..16) |op| {
            var test_reg = sample.before;
            exec(op, sample.instr[1], sample.instr[2], sample.instr[3], &test_reg);
            if (test_reg[0] == sample.after[0] and 
                test_reg[1] == sample.after[1] and 
                test_reg[2] == sample.after[2] and 
                test_reg[3] == sample.after[3]) {
                count += 1;
                mask |= @as(u16, 1) << @intCast(op);
            }
        }
        
        if (count >= 3) part1 += 1;
        candidates[sample.instr[0]] &= mask;
    }
    
    var mapping = [_]usize{0} ** 16;
    var found = [_]bool{false} ** 16;
    
    for (0..16) |_| {
        for (0..16) |i| {
            if (!found[i] and @popCount(candidates[i]) == 1) {
                const opcode = @ctz(candidates[i]);
                mapping[i] = opcode;
                found[i] = true;
                
                for (0..16) |j| {
                    candidates[j] &= ~(@as(u16, 1) << @intCast(opcode));
                }
                break;
            }
        }
    }
    
    var reg = [_]usize{0} ** 4;
    var prog_lines = std.mem.splitScalar(u8, program_part, '\n');
    while (prog_lines.next()) |line| {
        if (line.len == 0) continue;
        
        var nums: [4]usize = undefined;
        var i: usize = 0;
        var idx: usize = 0;
        while (i < line.len and idx < 4) {
            if (line[i] >= '0' and line[i] <= '9') {
                var n: usize = 0;
                while (i < line.len and line[i] >= '0' and line[i] <= '9') {
                    n = n * 10 + (line[i] - '0');
                    i += 1;
                }
                nums[idx] = n;
                idx += 1;
            } else {
                i += 1;
            }
        }
        
        if (idx == 4) {
            exec(mapping[nums[0]], nums[1], nums[2], nums[3], &reg);
        }
    }
    
    return Result{ .p1 = part1, .p2 = reg[0] };
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
