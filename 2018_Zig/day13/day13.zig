const std = @import("std");

const Result = struct { p1: [8:0]u8, p2: [8:0]u8 };

const Cart = struct {
    y: i32,
    x: i32,
    dir: u8,
    state: i8,
    
    fn lessThan(_: void, a: Cart, b: Cart) bool {
        if (a.y == b.y) return a.x < b.x;
        return a.y < b.y;
    }
};

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var grid: [256][256]u8 = undefined;
    var carts = std.ArrayList(Cart){};
    defer carts.deinit(allocator);
    
    var x: i32 = 0;
    var y: i32 = 0;
    
    for (input) |c| {
        if (c == '\n') {
            y += 1;
            x = 0;
        } else {
            grid[@intCast(y)][@intCast(x)] = c ^ 0x80;
            switch (c) {
                '^' => carts.append(allocator, .{ .y = y, .x = x, .dir = 0, .state = 0 }) catch unreachable,
                '>' => carts.append(allocator, .{ .y = y, .x = x, .dir = 1, .state = 0 }) catch unreachable,
                'v' => carts.append(allocator, .{ .y = y, .x = x, .dir = 2, .state = 0 }) catch unreachable,
                '<' => carts.append(allocator, .{ .y = y, .x = x, .dir = 3, .state = 0 }) catch unreachable,
                else => grid[@intCast(y)][@intCast(x)] ^= 0x80,
            }
            x += 1;
        }
    }
    
    var n_carts: i32 = @intCast(carts.items.len);
    var part1_x: i32 = 0;
    var part1_y: i32 = 0;
    var part1_found = false;
    var part2_x: i32 = 0;
    var part2_y: i32 = 0;
    
    const dy = [_]i32{ -1, 0, 1, 0 };
    const dx = [_]i32{ 0, 1, 0, -1 };
    const turn0 = [_]u8{ 3, 2, 1, 0 };
    const turn1 = [_]u8{ 1, 0, 3, 2 };
    
    while (n_carts != 1) {
        std.mem.sort(Cart, carts.items, {}, Cart.lessThan);
        
        while (carts.items.len > 0 and carts.items[carts.items.len - 1].state == -1) {
            _ = carts.pop();
        }
        
        for (carts.items) |*cart| {
            const uy: usize = @intCast(cart.y);
            const ux: usize = @intCast(cart.x);
            
            if ((grid[uy][ux] & 0x80) == 0) {
                cart.state = -1;
                cart.y = std.math.maxInt(i32);
                continue;
            }
            
            grid[uy][ux] &= 0x7f;
            
            cart.y += dy[cart.dir];
            cart.x += dx[cart.dir];
            
            const ny: usize = @intCast(cart.y);
            const nx: usize = @intCast(cart.x);
            
            if ((grid[ny][nx] & 0x80) != 0) {
                grid[ny][nx] &= 0x7f;
                cart.state = -1;
                n_carts -= 2;
                
                if (!part1_found) {
                    part1_x = cart.x;
                    part1_y = cart.y;
                    part1_found = true;
                }
                
                cart.y = std.math.maxInt(i32);
            } else {
                switch (grid[ny][nx]) {
                    '\\' => cart.dir = turn0[cart.dir],
                    '/' => cart.dir = turn1[cart.dir],
                    '+' => {
                        switch (cart.state) {
                            0 => {
                                cart.state = 1;
                                cart.dir = (cart.dir + 3) & 3;
                            },
                            1 => cart.state = 2,
                            2 => {
                                cart.state = 0;
                                cart.dir = (cart.dir + 1) & 3;
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
                grid[ny][nx] ^= 0x80;
            }
        }
    }
    
    for (carts.items) |cart| {
        const ny: usize = @intCast(cart.y);
        const nx: usize = @intCast(cart.x);
        if (cart.state != -1 and (grid[ny][nx] & 0x80) != 0) {
            part2_x = cart.x;
            part2_y = cart.y;
            break;
        }
    }
    
    var part1: [8:0]u8 = undefined;
    const p1_str = std.fmt.bufPrint(&part1, "{},{}", .{ part1_x, part1_y }) catch unreachable;
    part1[p1_str.len] = 0;
    
    var part2: [8:0]u8 = undefined;
    const p2_str = std.fmt.bufPrint(&part2, "{},{}", .{ part2_x, part2_y }) catch unreachable;
    part2[p2_str.len] = 0;
    
    return Result{ .p1 = part1, .p2 = part2 };
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
