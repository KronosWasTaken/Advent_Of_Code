// Host side of the Day 04 GPU search. Loads the NVIDIA driver at runtime and launches the
// PTX kernel from day04_gpu_kernel.zig, so no CUDA toolkit or nvcc is needed to build it.
const std = @import("std");

const ptx = @embedFile("day04_gpu_kernel.ptx");
const cpu = @import("day04_cpu_assist.zig");

const CUresult = c_int;
const CUdevice = c_int;
const CUcontext = ?*anyopaque;
const CUmodule = ?*anyopaque;
const CUfunction = ?*anyopaque;
const CUdeviceptr = u64;

const Driver = struct {
    init: *const fn (c_uint) callconv(.c) CUresult,
    deviceGet: *const fn (*CUdevice, c_int) callconv(.c) CUresult,
    ctxRetain: *const fn (*CUcontext, CUdevice) callconv(.c) CUresult,
    ctxSetCurrent: *const fn (CUcontext) callconv(.c) CUresult,
    moduleLoadData: *const fn (*CUmodule, *const anyopaque) callconv(.c) CUresult,
    moduleGetFunction: *const fn (*CUfunction, CUmodule, [*:0]const u8) callconv(.c) CUresult,
    memAlloc: *const fn (*CUdeviceptr, usize) callconv(.c) CUresult,
    memFree: *const fn (CUdeviceptr) callconv(.c) CUresult,
    memset32: *const fn (CUdeviceptr, u32, usize) callconv(.c) CUresult,
    memcpyDtoH: *const fn (*anyopaque, CUdeviceptr, usize) callconv(.c) CUresult,
    launch: *const fn (CUfunction, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, ?*anyopaque, [*]?*anyopaque, ?*anyopaque) callconv(.c) CUresult,
    sync: *const fn () callconv(.c) CUresult,
    streamQuery: *const fn (?*anyopaque) callconv(.c) CUresult,
};

fn loadDriver(lib: *std.DynLib) !Driver {
    return .{
        .init = lib.lookup(*const fn (c_uint) callconv(.c) CUresult, "cuInit") orelse return error.MissingSymbol,
        .deviceGet = lib.lookup(*const fn (*CUdevice, c_int) callconv(.c) CUresult, "cuDeviceGet") orelse return error.MissingSymbol,
        .ctxRetain = lib.lookup(*const fn (*CUcontext, CUdevice) callconv(.c) CUresult, "cuDevicePrimaryCtxRetain") orelse return error.MissingSymbol,
        .ctxSetCurrent = lib.lookup(*const fn (CUcontext) callconv(.c) CUresult, "cuCtxSetCurrent") orelse return error.MissingSymbol,
        .moduleLoadData = lib.lookup(*const fn (*CUmodule, *const anyopaque) callconv(.c) CUresult, "cuModuleLoadData") orelse return error.MissingSymbol,
        .moduleGetFunction = lib.lookup(*const fn (*CUfunction, CUmodule, [*:0]const u8) callconv(.c) CUresult, "cuModuleGetFunction") orelse return error.MissingSymbol,
        .memAlloc = lib.lookup(*const fn (*CUdeviceptr, usize) callconv(.c) CUresult, "cuMemAlloc_v2") orelse return error.MissingSymbol,
        .memFree = lib.lookup(*const fn (CUdeviceptr) callconv(.c) CUresult, "cuMemFree_v2") orelse return error.MissingSymbol,
        .memset32 = lib.lookup(*const fn (CUdeviceptr, u32, usize) callconv(.c) CUresult, "cuMemsetD32_v2") orelse return error.MissingSymbol,
        .memcpyDtoH = lib.lookup(*const fn (*anyopaque, CUdeviceptr, usize) callconv(.c) CUresult, "cuMemcpyDtoH_v2") orelse return error.MissingSymbol,
        .launch = lib.lookup(*const fn (CUfunction, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, ?*anyopaque, [*]?*anyopaque, ?*anyopaque) callconv(.c) CUresult, "cuLaunchKernel") orelse return error.MissingSymbol,
        .sync = lib.lookup(*const fn () callconv(.c) CUresult, "cuCtxSynchronize") orelse return error.MissingSymbol,
        .streamQuery = lib.lookup(*const fn (?*anyopaque) callconv(.c) CUresult, "cuStreamQuery") orelse return error.MissingSymbol,    };
}

const threads: c_uint = 128;

// Each GPU thread checks one decade of numbers; 10^6 decades cover every n below 10^7.
const decades: u32 = 1_000_000;
// The GPU starts on the decades below gpu_decades and the CPU threads on the seven-digit
// numbers above, sized so both usually finish together.
const gpu_decades: u32 = 950_000;
const helpers = 11;
const debug_split = false;
const main_works = true;

// Launches the kernel on decades [start, end).
fn search(drv: *const Driver, fun: CUfunction, start: u32, end: u32, d_best: CUdeviceptr) !void {
    var s = start;
    var e = end;
    var best = d_best;
    // Always 1. It is a launch parameter so ptxas cannot see the value; the kernel multiplies by
    // it to push its adds onto the FMA pipe (see madOne in the kernel).
    var one: u32 = 1;
    var params = [_]?*anyopaque{ &s, &e, &best, &one };
    const blocks: c_uint = (end - start + threads - 1) / threads;
    if (drv.launch(fun, blocks, 1, 1, threads, 1, 1, 0, null, &params, null) != 0) return error.LaunchFailed;
    // Under WDDM a launch can sit in the driver's batch; a query pushes it to the GPU now.
    _ = drv.streamQuery(null);
}

pub fn main() !void {
    var lib = try std.DynLib.open("nvcuda.dll");
    defer lib.close();
    const drv = try loadDriver(&lib);

    if (drv.init(0) != 0) return error.InitFailed;
    var dev: CUdevice = undefined;
    if (drv.deviceGet(&dev, 0) != 0) return error.NoDevice;
    var ctx: CUcontext = undefined;
    if (drv.ctxRetain(&ctx, dev) != 0) return error.ContextFailed;
    if (drv.ctxSetCurrent(ctx) != 0) return error.ContextFailed;

    var module: CUmodule = undefined;
    if (drv.moduleLoadData(&module, ptx.ptr) != 0) return error.ModuleFailed;
    var fun: CUfunction = undefined;
    if (drv.moduleGetFunction(&fun, module, "search") != 0) return error.ModuleFailed;

    var d_best: CUdeviceptr = undefined;
    if (drv.memAlloc(&d_best, 8) != 0) return error.AllocFailed;
    _ = drv.memset32(d_best, 0xFFFFFFFF, 2);
    // The memset is the first GPU work in the process and returns before it finishes; without
    // this wait its completion (and the context's first-submission cost, ~300 us) would land
    // inside the timed region below.
    if (drv.sync() != 0) return error.SetupFailed;

    // Helper threads are set up with the rest of the GPU context: started now and spinning, so
    // waking them is not part of the timed solve. They do no work until `go` is set.
    var shared = cpu.Shared{ .lo = gpu_decades * 10, .chunks = (decades - gpu_decades) / 100 };
    var started: u32 = 0;
    for (0..helpers) |_| {
        const t = std.Thread.spawn(.{ .stack_size = 64 * 1024 }, cpu.Shared.helper, .{&shared}) catch continue;
        t.detach();
        started += 1;
    }
    while (shared.ready.load(.acquire) < started) std.atomic.spinLoopHint();

    var timer = try std.time.Timer.start();
    shared.start();
    try search(&drv, fun, 0, gpu_decades, d_best);

    // The main thread hashes CPU chunks too while the GPU runs. If the GPU finishes first, the
    // chunks nobody has claimed yet go back to the GPU.
    var cpu_chunks = shared.chunks;
    while (true) {
        if (drv.streamQuery(null) == 0) {
            const first = shared.next.swap(shared.chunks, .monotonic);
            if (first < shared.chunks) {
                cpu_chunks = first;
                try search(&drv, fun, gpu_decades + first * 100, decades, d_best);
            }
            break;
        }
        if (main_works) {
            if (!shared.workOne()) break;
        } else if (shared.next.load(.monotonic) >= shared.chunks) break;
    }
    const t_loop = timer.read();
    var p: [2]u32 = undefined;
    // A synchronous copy waits for every kernel launched so far.
    if (drv.memcpyDtoH(&p, d_best, 8) != 0) return error.LaunchFailed;
    const t_gpu = timer.read();
    while (shared.done.load(.acquire) < cpu_chunks) std.atomic.spinLoopHint();
    p[0] = @min(p[0], shared.best[0].load(.monotonic));
    p[1] = @min(p[1], shared.best[1].load(.monotonic));
    const us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    if (debug_split) std.debug.print("loop {d:.0} gpu {d:.0} cpu chunks {}/{}\n", .{ @as(f64, @floatFromInt(t_loop)) / 1000.0, @as(f64, @floatFromInt(t_gpu)) / 1000.0, cpu_chunks, shared.chunks });

    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ p[0], p[1] });
    std.debug.print("Time: {d:.2} microseconds\n", .{us});
}
