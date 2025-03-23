const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get dependencies
    const zglfw_dep = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    const zmath_dep = b.dependency("zmath", .{
        .target = target,
        .optimize = optimize,
    });

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "Vibe_Code_Test",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies to the executable
    exe.root_module.addImport("zglfw", zglfw_dep.module("root"));
    exe.root_module.addImport("zmath", zmath_dep.module("root"));

    // Link system libraries
    exe.linkLibC();

    // Link native libraries required for zglfw
    const os = target.result.os.tag;
    if (os != .emscripten) {
        exe.linkLibrary(zglfw_dep.artifact("glfw"));
    }
    if (os == .windows) {
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("kernel32");
        exe.linkSystemLibrary("opengl32");
    } else if (os == .linux) {
        // Linux dependencies
        exe.linkSystemLibrary("X11");
        exe.linkSystemLibrary("GL");
        exe.linkSystemLibrary("vulkan");
        exe.linkSystemLibrary("glfw");
    } else if (os == .macos) {
        // MacOS dependencies
        exe.linkFramework("AppKit");
        exe.linkFramework("CoreFoundation");
        exe.linkFramework("CoreGraphics");
        exe.linkFramework("Foundation");
        exe.linkFramework("Metal");
        exe.linkFramework("QuartzCore"); // CALayer
    }

    // Install necessary artifacts from dependencies
    zglfw_dep.builder.installArtifact(exe);

    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Create test step
    const exe_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}