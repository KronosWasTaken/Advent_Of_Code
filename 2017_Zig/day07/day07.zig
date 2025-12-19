const std = @import("std");
const Result = struct { p1: []const u8, p2: i32 };
const Node = struct {
    has_parent: bool = false,
    parent: usize = 0,
    children: usize = 0,
    processed: usize = 0,
    weight: i32 = 0,
    total: i32 = 0,
    sub_weights: [2]i32 = [_]i32{0} ** 2,
    sub_totals: [2]i32 = [_]i32{0} ** 2,
};
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var lines_list: std.ArrayList([]const u8) = .{};
    defer lines_list.deinit(gpa);
    var name_to_idx = std.StringHashMap(usize).init(gpa);
    defer name_to_idx.deinit();
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    var idx: usize = 0;
    while (lines.next()) |line| {
        const space_pos = std.mem.indexOfScalar(u8, line, ' ') orelse continue;
        const name = line[0..space_pos];
        name_to_idx.put(name, idx) catch unreachable;
        lines_list.append(gpa, line) catch unreachable;
        idx += 1;
    }
    var nodes: std.ArrayList(Node) = .{};
    defer nodes.deinit(gpa);
    nodes.appendNTimes(gpa, Node{}, lines_list.items.len) catch unreachable;
    var todo: std.ArrayList(usize) = .{};
    defer todo.deinit(gpa);
    for (lines_list.items, 0..) |line, i| {
        const space_pos = std.mem.indexOfScalar(u8, line, ' ') orelse continue;
        const suffix = line[space_pos + 1 ..];
        var weight: i32 = 0;
        var parsing_weight = false;
        var weight_str: std.ArrayList(u8) = .{};
        defer weight_str.deinit(gpa);
        for (suffix) |c| {
            if (c == '(') parsing_weight = true
            else if (c == ')') {
                weight = std.fmt.parseInt(i32, weight_str.items, 10) catch 0;
                parsing_weight = false;
            } else if (parsing_weight and (c >= '0' and c <= '9')) {
                weight_str.append(gpa, c) catch unreachable;
            }
        }
        nodes.items[i].weight = weight;
        nodes.items[i].total = weight;
        if (std.mem.indexOf(u8, suffix, "->")) |arrow_pos| {
            var child_tokens = std.mem.tokenizeAny(u8, suffix[arrow_pos + 2 ..], ", ");
            while (child_tokens.next()) |child_name| {
                nodes.items[i].children += 1;
                const child_idx = name_to_idx.get(child_name) orelse continue;
                nodes.items[child_idx].parent = i;
                nodes.items[child_idx].has_parent = true;
            }
        }
        if (nodes.items[i].children == 0) {
            todo.append(gpa, i) catch unreachable;
        }
    }
    var root_name: []const u8 = "";
    for (lines_list.items, 0..) |line, i| {
        if (!nodes.items[i].has_parent) {
            const space_pos = std.mem.indexOfScalar(u8, line, ' ') orelse continue;
            root_name = line[0..space_pos];
            break;
        }
    }
    var p2: i32 = 0;
    var todo_idx: usize = 0;
    while (todo_idx < todo.items.len) : (todo_idx += 1) {
        const index = todo.items[todo_idx];
        const parent = nodes.items[index].parent;
        const weight = nodes.items[index].weight;
        const total = nodes.items[index].total;
        if (nodes.items[parent].processed < 2) {
            nodes.items[parent].sub_weights[nodes.items[parent].processed] = weight;
            nodes.items[parent].sub_totals[nodes.items[parent].processed] = total;
        } else {
            if (nodes.items[parent].sub_totals[0] == total) {
                const tmp_w = nodes.items[parent].sub_weights[0];
                const tmp_t = nodes.items[parent].sub_totals[0];
                nodes.items[parent].sub_weights[0] = nodes.items[parent].sub_weights[1];
                nodes.items[parent].sub_totals[0] = nodes.items[parent].sub_totals[1];
                nodes.items[parent].sub_weights[1] = tmp_w;
                nodes.items[parent].sub_totals[1] = tmp_t;
            } else if (nodes.items[parent].sub_totals[1] != total) {
                nodes.items[parent].sub_weights[0] = weight;
                nodes.items[parent].sub_totals[0] = total;
            }
        }
        nodes.items[parent].total += total;
        nodes.items[parent].processed += 1;
        if (nodes.items[parent].processed == nodes.items[parent].children) {
            todo.append(gpa, parent) catch unreachable;
            if (nodes.items[parent].children >= 3) {
                const w = nodes.items[parent].sub_weights[0];
                const x = nodes.items[parent].sub_totals[0];
                const y = nodes.items[parent].sub_totals[1];
                if (x != y) {
                    p2 = w - x + y;
                    break;
                }
            }
        }
    }
    return .{ .p1 = root_name, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var total: u64 = 0;
    const iterations = 1000;
    var result: Result = undefined;
    for (0..iterations) |_| {
        var timer = try std.time.Timer.start();
        result = solve(input);
        total += timer.read();
    }
    const avg_ns = total / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{avg_us});
}
