const std = @import("std");
const math = std.math;
const zglfw = @import("zglfw");
const zmath = @import("zmath");

const window_title = "OpenGL GLFW Window";
const window_width = 800;
const window_height = 600;

// Triangle vertex data
const vertices = [_]f32{
    // Positions        // Colors
    -0.5, -0.5, 0.0,    1.0, 0.0, 0.0, // Bottom left - red
     0.5, -0.5, 0.0,    0.0, 1.0, 0.0, // Bottom right - green
     0.0,  0.5, 0.0,    0.0, 0.0, 1.0, // Top - blue
};

// GL objects
var vao: c_uint = 0;
var vbo: c_uint = 0;
var shader_program: c_uint = 0;

// OpenGL function pointers
const GL = struct {
    var glGenVertexArrays: *const fn(n: c_int, arrays: [*c]c_uint) callconv(.C) void = undefined;
    var glGenBuffers: *const fn(n: c_int, buffers: [*c]c_uint) callconv(.C) void = undefined;
    var glBindVertexArray: *const fn(array: c_uint) callconv(.C) void = undefined;
    var glBindBuffer: *const fn(target: c_uint, buffer: c_uint) callconv(.C) void = undefined;
    var glBufferData: *const fn(target: c_uint, size: c_long, data: ?*const anyopaque, usage: c_uint) callconv(.C) void = undefined;
    var glVertexAttribPointer: *const fn(index: c_uint, size: c_int, type: c_uint, normalized: u8, stride: c_int, pointer: usize) callconv(.C) void = undefined;
    var glEnableVertexAttribArray: *const fn(index: c_uint) callconv(.C) void = undefined;
    var glCreateShader: *const fn(shader_type: c_uint) callconv(.C) c_uint = undefined;
    var glShaderSource: *const fn(shader: c_uint, count: c_int, string: [*c]const [*c]const u8, length: [*c]const c_int) callconv(.C) void = undefined;
    var glCompileShader: *const fn(shader: c_uint) callconv(.C) void = undefined;
    var glGetShaderiv: *const fn(shader: c_uint, pname: c_uint, params: [*c]c_int) callconv(.C) void = undefined;
    var glGetShaderInfoLog: *const fn(shader: c_uint, maxLength: c_int, length: [*c]c_int, infoLog: [*c]u8) callconv(.C) void = undefined;
    var glCreateProgram: *const fn() callconv(.C) c_uint = undefined;
    var glAttachShader: *const fn(program: c_uint, shader: c_uint) callconv(.C) void = undefined;
    var glLinkProgram: *const fn(program: c_uint) callconv(.C) void = undefined;
    var glGetProgramiv: *const fn(program: c_uint, pname: c_uint, params: [*c]c_int) callconv(.C) void = undefined;
    var glGetProgramInfoLog: *const fn(program: c_uint, maxLength: c_int, length: [*c]c_int, infoLog: [*c]u8) callconv(.C) void = undefined;
    var glDeleteShader: *const fn(shader: c_uint) callconv(.C) void = undefined;
    var glUseProgram: *const fn(program: c_uint) callconv(.C) void = undefined;
    var glClear: *const fn(mask: c_uint) callconv(.C) void = undefined;
    var glClearColor: *const fn(r: f32, g: f32, b: f32, a: f32) callconv(.C) void = undefined;
    var glDrawArrays: *const fn(mode: c_uint, first: c_int, count: c_int) callconv(.C) void = undefined;
};

const GL_ARRAY_BUFFER = 0x8892;
const GL_STATIC_DRAW = 0x88E4;
const GL_FLOAT = 0x1406;
const GL_FALSE = 0;
const GL_VERTEX_SHADER = 0x8B31;
const GL_FRAGMENT_SHADER = 0x8B30;
const GL_COMPILE_STATUS = 0x8B81;
const GL_LINK_STATUS = 0x8B82;
const GL_COLOR_BUFFER_BIT = 0x00004000;
const GL_TRIANGLES = 0x0004;

// Vertex shader source
const vertex_shader_source =
    \#version 330 core
    \layout (location = 0) in vec3 aPos;
    \layout (location = 1) in vec3 aColor;
    \out vec3 vertexColor;
    \void main() {
    \    gl_Position = vec4(aPos, 1.0);
    \    vertexColor = aColor;
    \}
;

// Fragment shader source
const fragment_shader_source =
    \#version 330 core
    \in vec3 vertexColor;
    \out vec4 FragColor;
    \void main() {
    \    FragColor = vec4(vertexColor, 1.0);
    \}
;

// Function to load OpenGL function pointers
fn loadGLFunctions() !void {
    inline for (@typeInfo(GL).Struct.fields) |field| {
        const name = field.name;
        
        if (zglfw.getProcAddress(name)) |proc_addr| {
            @field(GL, name) = @ptrCast(proc_addr);
        } else {
            std.debug.print("Failed to load OpenGL function: {s}\n", .{name});
            return error.FailedToLoadOpenGLFunction;
        }
    }
}

// Create and compile a shader
fn createShader(shader_type: c_uint, source: [*:0]const u8) !c_uint {
    const shader = GL.glCreateShader(shader_type);
    const sources = [_][*c]const u8{@ptrCast(source)};
    const lengths = [_]c_int{-1}; // Assume null-terminated
    
    GL.glShaderSource(shader, 1, &sources, &lengths);
    GL.glCompileShader(shader);
    
    // Check compilation status
    var success: c_int = 0;
    GL.glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    
    if (success == GL_FALSE) {
        var info_log: [512]u8 = undefined;
        var length: c_int = 0;
        GL.glGetShaderInfoLog(shader, 512, &length, &info_log);
        std.debug.print("Shader compilation error: {s}\n", .{info_log[0..@intCast(length)]});
        return error.ShaderCompilationError;
    }
    
    return shader;
}

// Create a shader program
fn createShaderProgram(vertex_shader: c_uint, fragment_shader: c_uint) !c_uint {
    const program = GL.glCreateProgram();
    GL.glAttachShader(program, vertex_shader);
    GL.glAttachShader(program, fragment_shader);
    GL.glLinkProgram(program);
    
    // Check link status
    var success: c_int = 0;
    GL.glGetProgramiv(program, GL_LINK_STATUS, &success);
    
    if (success == GL_FALSE) {
        var info_log: [512]u8 = undefined;
        var length: c_int = 0;
        GL.glGetProgramInfoLog(program, 512, &length, &info_log);
        std.debug.print("Shader program linking error: {s}\n", .{info_log[0..@intCast(length)]});
        return error.ShaderLinkingError;
    }
    
    return program;
}

// Initialize OpenGL objects
fn initGL() !void {
    try loadGLFunctions();
    
    // Create and compile shaders
    const vertex_shader = try createShader(GL_VERTEX_SHADER, vertex_shader_source);
    defer GL.glDeleteShader(vertex_shader);
    
    const fragment_shader = try createShader(GL_FRAGMENT_SHADER, fragment_shader_source);
    defer GL.glDeleteShader(fragment_shader);
    
    // Create shader program
    shader_program = try createShaderProgram(vertex_shader, fragment_shader);
    
    // Generate and set up vertex array object (VAO) and vertex buffer object (VBO)
    GL.glGenVertexArrays(1, &vao);
    GL.glGenBuffers(1, &vbo);
    
    // Bind VAO first, then bind and set VBO, and configure vertex attributes
    GL.glBindVertexArray(vao);
    
    GL.glBindBuffer(GL_ARRAY_BUFFER, vbo);
    GL.glBufferData(GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, GL_STATIC_DRAW);
    
    // Position attribute
    GL.glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * @sizeOf(f32), 0);
    GL.glEnableVertexAttribArray(0);
    
    // Color attribute
    GL.glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * @sizeOf(f32), 3 * @sizeOf(f32));
    GL.glEnableVertexAttribArray(1);
    
    // Unbind the VAO and VBO
    GL.glBindBuffer(GL_ARRAY_BUFFER, 0);
    GL.glBindVertexArray(0);
}

pub fn main() !void {
    // Initialize GLFW using zglfw wrapper
    try zglfw.init();
    defer zglfw.terminate();

    // Configure GLFW window hints using zglfw
    zglfw.WindowHint.set(.context_version_major, 3);
    zglfw.WindowHint.set(.context_version_minor, 3);
    zglfw.WindowHint.set(.opengl_profile, .opengl_core_profile);
    zglfw.WindowHint.set(.resizable, true);
    
    // Create window using zglfw
    const window = try zglfw.Window.create(
        window_width,
        window_height,
        window_title,
        null
    );
    defer window.destroy();
    
    // Set window size limits using zglfw
    window.setSizeLimits(400, 400, -1, -1);

    // Make the OpenGL context current
    zglfw.makeContextCurrent(window);
    
    // Initialize OpenGL functions and objects
    try initGL();
    
    // Print OpenGL version
    if (zglfw.getProcAddress("glGetString")) |proc_addr| {
        const glGetString = @as(
            *const fn (c_uint) callconv(.C) ?[*:0]const u8, 
            @ptrCast(proc_addr)
        );
        
        if (glGetString(0x1F02)) |version| { // GL_VERSION
            std.debug.print("OpenGL Version: {s}\n", .{version});
        }
    }
    
    // Variables for timing
    var prev_time = @as(f32, @floatCast(zglfw.getTime()));
    var frame_count: u32 = 0;
    var last_fps_time = prev_time;

    // Main loop
    while (zglfw.windowShouldClose(window) == false) {
        zglfw.pollEvents();
        
        // Calculate delta time and FPS
        const current_time = @as(f32, @floatCast(zglfw.getTime()));
        _ = current_time - prev_time;
        prev_time = current_time;
        
        frame_count += 1;
        if (current_time - last_fps_time >= 1.0) {
            std.debug.print("FPS: {}\n", .{frame_count});
            frame_count = 0;
            last_fps_time = current_time;
        }
        
        // Clear the screen
        GL.glClearColor(0.1, 0.2, 0.3, 1.0);
        GL.glClear(GL_COLOR_BUFFER_BIT);
        
        // Render the triangle
        GL.glUseProgram(shader_program);
        GL.glBindVertexArray(vao);
        GL.glDrawArrays(GL_TRIANGLES, 0, 3);
        
        // Swap buffers
        zglfw.swapBuffers(window);
    }
}