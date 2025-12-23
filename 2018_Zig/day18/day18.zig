const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

const LOWER: u64 = 0x0f0f0f0f0f0f0f0f;
const UPPER: u64 = 0xf0f0f0f0f0f0f0f0;
const EDGE: u64 = 0xffff000000000000;

fn step(area: []u64, rows: []u64) void {
    
    for (0..50) |y| {
        const area_row = area[7 * y ..];
        const rows_row = rows[7 * (y + 1) ..];
        
        rows_row[0] = horizontalSum(0, area_row[0], area_row[1]);
        rows_row[1] = horizontalSum(area_row[0], area_row[1], area_row[2]);
        rows_row[2] = horizontalSum(area_row[1], area_row[2], area_row[3]);
        rows_row[3] = horizontalSum(area_row[2], area_row[3], area_row[4]);
        rows_row[4] = horizontalSum(area_row[3], area_row[4], area_row[5]);
        rows_row[5] = horizontalSum(area_row[4], area_row[5], area_row[6]);
        rows_row[6] = horizontalSum(area_row[5], area_row[6], 0);
        
        rows_row[6] &= EDGE;
    }
    
    
    for (0..350) |i| {
        const acre = area[i];
        const sum = rows[i] + rows[i + 7] + rows[i + 14] - acre;
        
        
        var to_tree = (sum & LOWER) + 0x0d0d0d0d0d0d0d0d;
        to_tree &= UPPER;
        to_tree &= ~(acre | (acre << 4));
        to_tree >>= 4;
        
        
        var to_lumberyard = ((sum >> 4) & LOWER) + 0x0d0d0d0d0d0d0d0d;
        to_lumberyard &= UPPER;
        to_lumberyard &= acre << 4;
        to_lumberyard |= to_lumberyard >> 4;
        
        
        var to_open = acre & UPPER;
        to_open &= (sum & LOWER) + 0x0f0f0f0f0f0f0f0f;
        to_open &= ((sum >> 4) & LOWER) + 0x0f0f0f0f0f0f0f0f;
        to_open ^= acre & UPPER;
        
        area[i] = acre ^ (to_tree | to_lumberyard | to_open);
    }
}

fn horizontalSum(left: u64, middle: u64, right: u64) u64 {
    return (left << 56) + (middle >> 8) + middle + (middle << 8) + (right >> 56);
}

fn resourceValue(area: []const u64) u32 {
    var trees: u32 = 0;
    var lumberyards: u32 = 0;
    for (area) |n| {
        trees += @popCount(n & LOWER);
        lumberyards += @popCount(n & UPPER);
    }
    return trees * lumberyards;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var area = allocator.alloc(u64, 350) catch unreachable;
    @memset(area, 0);
    
    var line_length: usize = 0;
    for (input, 0..) |c, i| {
        if (c == '\n') {
            line_length = if (i > 0 and input[i-1] == '\r') i + 1 else i + 1;
            break;
        }
    }
    if (line_length == 0) line_length = input.len;
    
    for (input, 0..) |c, idx| {
        const x = idx % line_length; 
        const y = idx / line_length;
        if (x >= 50 or y >= 50) continue;
        
        const acre: u64 = switch (c) {
            '|' => 0x01,
            '#' => 0x10,
            else => 0x00,
        };
        
        const area_idx = (y * 7) + (x / 8);
        const offset: u6 = @intCast(56 - 8 * (x % 8));
        area[area_idx] |= acre << offset;
    }
    
    const rows = allocator.alloc(u64, 364) catch unreachable;
    @memset(rows, 0);
    
    for (0..10) |_| {
        step(area, rows);
    }
    const part1 = resourceValue(area);
    
    var history = std.ArrayList([350]u64){};
    var seen = std.AutoHashMap(u128, std.ArrayList(usize)).init(allocator);
    
    var minute: usize = 10;
    
    while (minute < 1_000_000_000) : (minute += 1) {
        const hash: u128 = (@as(u128, area[50]) << 64) | 
                           (@as(u128, area[150]) << 32) | 
                           (@as(u128, area[250]) >> 32);
        
        var found_cycle = false;
        var cycle_start: usize = 0;
        
        if (seen.get(hash)) |candidates| {
            for (candidates.items) |idx| {
                if (std.mem.eql(u64, &history.items[idx], area)) {
                    found_cycle = true;
                    cycle_start = idx + 10;
                    break;
                }
            }
        }
        
        if (found_cycle) {
            const cycle_length = minute - cycle_start;
            const target_minute = cycle_start + ((1_000_000_000 - cycle_start) % cycle_length);
            
            const target_idx = target_minute - 10;
            @memcpy(area, &history.items[target_idx]);
            break;
        }
        
        var state: [350]u64 = undefined;
        @memcpy(&state, area);
        const hist_idx = history.items.len;
        history.append(allocator, state) catch unreachable;
        
        if (seen.getPtr(hash)) |list| {
            list.append(allocator, hist_idx) catch unreachable;
        } else {
            var list = std.ArrayList(usize){};
            list.append(allocator, hist_idx) catch unreachable;
            seen.put(hash, list) catch unreachable;
        }
        
        step(area, rows);
        
        if (minute > 10000) break;
    }
    
    const part2 = resourceValue(area);
    
    return Result{ .p1 = part1, .p2 = part2 };
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
