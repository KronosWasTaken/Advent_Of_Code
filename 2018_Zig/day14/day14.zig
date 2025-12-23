const std = @import("std");

const Result = struct { p1: [10:0]u8, p2: usize };

const PREFIX = [_]u8{3, 7, 1, 0, 1, 0, 1, 2, 4, 5, 1, 5, 8, 9, 1, 6, 7, 7, 9, 2, 5, 1, 0};

const SharedState = struct {
    recipes: []u8,
    snack: []u8,
    size: std.atomic.Value(usize),
    target: u32,
    pattern: [8]u8,
    pattern_len: usize,
    last_digit: u8,
    part2_result: std.atomic.Value(usize),
    part2_found: std.atomic.Value(bool),
    writer_done: std.atomic.Value(bool),
};

fn readerThread(state: *SharedState) void {
    var last_checked: usize = 0;
    
    while (!state.writer_done.load(.acquire) or !state.part2_found.load(.acquire)) {
        const size = state.size.load(.acquire);
        
        if (size > last_checked) {
            
            for (last_checked..size) |i| {
                
                if (state.recipes[i] == state.last_digit) {
                    
                    if (i + 1 >= state.pattern_len) {
                        const start = i + 1 - state.pattern_len;
                        var match = true;
                        
                        for (0..state.pattern_len) |j| {
                            if (state.recipes[start + j] != state.pattern[j]) {
                                match = false;
                                break;
                            }
                        }
                        
                        if (match) {
                            state.part2_result.store(start, .release);
                            state.part2_found.store(true, .release);
                            return;
                        }
                    }
                }
            }
            last_checked = size;
        }
        
        
        std.Thread.yield() catch {};
    }
}

fn solve(input: []const u8, allocator: std.mem.Allocator) Result {
    var target: u32 = 0;
    var pattern_len: usize = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            target = target * 10 + (c - '0');
            pattern_len += 1;
        }
    }
    
    
    var pattern: [8]u8 = undefined;
    var temp = target;
    var i: usize = pattern_len;
    while (i > 0) {
        i -= 1;
        pattern[i] = @intCast(temp % 10);
        temp /= 10;
    }
    
    const last_digit = pattern[pattern_len - 1];
    
    var recipes = allocator.alloc(u8, 22_000_000) catch unreachable;
    defer allocator.free(recipes);
    @memset(recipes, 1);
    @memcpy(recipes[0..23], &PREFIX);
    
    var snack = allocator.alloc(u8, 5_000_000) catch unreachable;
    defer allocator.free(snack);
    
    var state = SharedState{
        .recipes = recipes,
        .snack = snack,
        .size = std.atomic.Value(usize).init(23),
        .target = target,
        .pattern = pattern,
        .pattern_len = pattern_len,
        .last_digit = last_digit,
        .part2_result = std.atomic.Value(usize).init(0),
        .part2_found = std.atomic.Value(bool).init(false),
        .writer_done = std.atomic.Value(bool).init(false),
    };
    
    
    const reader = std.Thread.spawn(.{}, readerThread, .{&state}) catch unreachable;
    
    
    var size: usize = 23;
    var needed: usize = 23;
    var write: usize = 0;
    var elf1: usize = 0;
    var elf2: usize = 8;
    var index1: usize = 0;
    var index2: usize = 0;
    
    var part1: [10:0]u8 = undefined;
    var part1_found = false;
    
    while (!part1_found or !state.part2_found.load(.monotonic)) {
        
        while (elf1 < 23 or elf2 < 23 or (write > 0 and write - @max(index1, index2) <= 16)) {
            const recipe1 = if (elf1 < 23) PREFIX[elf1] else blk: {
                const r = snack[index1];
                index1 += 1;
                break :blk r;
            };
            
            const recipe2 = if (elf2 < 23) PREFIX[elf2] else blk: {
                const r = snack[index2];
                index2 += 1;
                break :blk r;
            };
            
            const next = recipe1 + recipe2;
            if (next < 10) {
                recipes[size] = next;
                size += 1;
            } else {
                recipes[size + 1] = next - 10;
                size += 2;
            }
            
            while (needed < size) {
                const digit = recipes[needed];
                needed += 1 + digit;
                snack[write] = digit;
                write += 1;
            }
            
            elf1 += 1 + recipe1;
            if (elf1 >= size) {
                elf1 -= size;
                index1 = 0;
            }
            
            elf2 += 1 + recipe2;
            if (elf2 >= size) {
                elf2 -= size;
                index2 = 0;
            }
        }
        
        
        const batch_size = @min(500, (write - @max(index1, index2) - 1) / 16);
        
        for (0..batch_size) |_| {
            for (0..16) |j| {
                const r1 = snack[index1 + j];
                const r2 = snack[index2 + j];
                
                const next = r1 + r2;
                if (next >= 10) {
                    recipes[size + 1] = next - 10;
                    size += 2;
                } else {
                    recipes[size] = next;
                    size += 1;
                }
                
                elf1 += 1 + r1;
                elf2 += 1 + r2;
            }
            
            index1 += 16;
            index2 += 16;
            
            while (needed < size) {
                const digit = recipes[needed];
                needed += 1 + digit;
                snack[write] = digit;
                write += 1;
            }
        }
        
        
        state.size.store(size, .release);
        
        
        if (!part1_found and size >= target + 10) {
            for (0..10) |k| {
                part1[k] = recipes[target + k] + '0';
            }
            part1[10] = 0;
            part1_found = true;
        }
        
        if (size >= 21_000_000) break;
    }
    
    state.writer_done.store(true, .release);
    state.size.store(size, .release);
    reader.join();
    
    const part2 = state.part2_result.load(.acquire);
    
    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input, allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
