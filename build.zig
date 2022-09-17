const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("CDS", "main.zig");
    lib.setBuildMode(mode);
    lib.setTarget(target);
    lib.install();

    const test_exe = b.addTest("main.zig");
    test_exe.setBuildMode(mode);
    test_exe.setTarget(target);

    const test_step = b.step("test", "Test CDS");
    test_step.dependOn(&test_exe.step);
}
