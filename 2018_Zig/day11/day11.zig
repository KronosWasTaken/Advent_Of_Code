const std = @import("std");

const Result = struct { p1: [8:0]u8, p2: [16:0]u8 };

const SearchResult = struct {
    x: usize,
    y: usize,
    size: usize,
    power: i32,
};

fn solve(input: []const u8) Result {
    
    var serial: i32 = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            serial = serial * 10 + @as(i32, c - '0');
        }
    }
    
    
    var sat: [301 * 301]i32 = undefined;
    @memset(&sat, 0);
    
    for (1..301) |y| {
        for (1..301) |x| {
            const rack_id = @as(i32, @intCast(x)) + 10;
            var power: i32 = rack_id * @as(i32, @intCast(y));
            power += serial;
            power *= rack_id;
            power = @rem(@divTrunc(power, 100), 10);
            power -= 5;
            
            const idx = 301 * y + x;
            sat[idx] = power + sat[idx - 1] + sat[idx - 301] - sat[idx - 302];
        }
    }
    
    
    var max_power_p1: i32 = std.math.minInt(i32);
    var best_x_p1: usize = 0;
    var best_y_p1: usize = 0;
    
    for (3..301) |y| {
        for (3..301) |x| {
            const idx = 301 * y + x;
            const power = sat[idx] - sat[idx - 3] - sat[idx - 301 * 3] + sat[idx - 302 * 3];
            
            if (power > max_power_p1) {
                max_power_p1 = power;
                best_x_p1 = x - 2;
                best_y_p1 = y - 2;
            }
        }
    }
    
    
    
    const num_threads = 8;
    const sizes_per_thread = 300 / num_threads;
    
    var threads: [num_threads]std.Thread = undefined;
    var results: [num_threads]SearchResult = undefined;
    
    var thread_data: [num_threads]ThreadDataType = undefined;
    
    
    for (0..num_threads) |i| {
        const start_size = 1 + i * sizes_per_thread;
        const end_size = if (i == num_threads - 1) 301 else start_size + sizes_per_thread;
        
        thread_data[i] = ThreadDataType{
            .sat_ptr = &sat,
            .start_size = start_size,
            .end_size = end_size,
            .result_ptr = &results[i],
        };
        
        threads[i] = std.Thread.spawn(.{}, searchSizes, .{thread_data[i]}) catch unreachable;
    }
    
    
    for (threads) |thread| {
        thread.join();
    }
    
    
    var max_power_p2: i32 = std.math.minInt(i32);
    var best_x_p2: usize = 0;
    var best_y_p2: usize = 0;
    var best_size: usize = 0;
    
    for (results) |res| {
        if (res.power > max_power_p2) {
            max_power_p2 = res.power;
            best_x_p2 = res.x;
            best_y_p2 = res.y;
            best_size = res.size;
        }
    }
    
    var part1: [8:0]u8 = undefined;
    const p1_str = std.fmt.bufPrint(&part1, "{},{}", .{ best_x_p1, best_y_p1 }) catch unreachable;
    part1[p1_str.len] = 0;
    
    var part2: [16:0]u8 = undefined;
    const p2_str = std.fmt.bufPrint(&part2, "{},{},{}", .{ best_x_p2, best_y_p2, best_size }) catch unreachable;
    part2[p2_str.len] = 0;
    
    return Result{ .p1 = part1, .p2 = part2 };
}

const ThreadDataType = struct {
    sat_ptr: *const [301 * 301]i32,
    start_size: usize,
    end_size: usize,
    result_ptr: *SearchResult,
};

fn searchSizes(data: ThreadDataType) void {
    const sat = data.sat_ptr;
    var max_power: i32 = std.math.minInt(i32);
    var max_x: usize = 0;
    var max_y: usize = 0;
    var max_size: usize = 0;
    
    for (data.start_size..data.end_size) |size| {
        for (size..301) |y| {
            for (size..301) |x| {
                const idx = 301 * y + x;
                const power = sat[idx] - sat[idx - size] - sat[idx - 301 * size] + sat[idx - 302 * size];
                
                if (power > max_power) {
                    max_power = power;
                    max_x = x - size + 1;
                    max_y = y - size + 1;
                    max_size = size;
                }
            }
        }
    }
    
    data.result_ptr.* = SearchResult{
        .x = max_x,
        .y = max_y,
        .size = max_size,
        .power = max_power,
    };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
