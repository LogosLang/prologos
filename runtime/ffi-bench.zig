// ffi-bench.zig — minimal Zig functions for FFI overhead microbench.
//
// Three exported functions for calibrating Racket → Zig FFI cost
// across a 10M-iteration loop:
//   ffi_bench_noop()                   — zero-arg, void return
//   ffi_bench_add(a: i64, b: i64) i64  — two i64 args + i64 return
//   ffi_bench_callback(fn_ptr) i64     — invokes a callback 1000 times
//                                        and returns sum (measures
//                                        Zig → Racket callback overhead)
//
// Compiled into libffi-bench.so for use from Racket via ffi/unsafe.

export fn ffi_bench_noop() void {}

export fn ffi_bench_add(a: i64, b: i64) i64 {
    return a + b;
}

// Callback bench: call the supplied function pointer 1000 times,
// passing iteration index, accumulating returned values into a sum.
// The caller divides total wall time by 1000 to get per-callback cost.
export fn ffi_bench_callback(callback: *const fn (i64) callconv(.C) i64) i64 {
    var sum: i64 = 0;
    var i: i64 = 0;
    while (i < 1000) : (i += 1) {
        sum +%= callback(i);
    }
    return sum;
}
