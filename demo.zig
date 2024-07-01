const std = @import("std");
const glfw = struct {
    const c = @cImport({
        @cInclude("GLFW/glfw3.h");
    });
    const Window = ?*c.GLFWwindow;
    fn check(rc: c_int) !void {
        if (rc != glfw.c.GLFW_TRUE) return error.Glfw;
    }
};

pub fn main() !void {
    try glfw.check(glfw.c.glfwInit());
    defer glfw.c.glfwTerminate();

    const window = glfw.c.glfwCreateWindow(640, 480, "Hello World", null, null) orelse return error.Glfw;
    defer glfw.c.glfwDestroyWindow(window);

    glfw.c.glfwMakeContextCurrent(window);

    _ = glfw.c.glfwSetKeyCallback(window, keyCallback);
    while (glfw.c.glfwWindowShouldClose(window) != glfw.c.GLFW_TRUE) {
        glfw.c.glClear(glfw.c.GL_COLOR_BUFFER_BIT);
        glfw.c.glfwSwapBuffers(window);
        glfw.c.glfwPollEvents();
    }
}

fn keyCallback(window: glfw.Window, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;
    if (key == glfw.c.GLFW_KEY_ESCAPE and action == glfw.c.GLFW_PRESS)
        glfw.c.glfwSetWindowShouldClose(window, glfw.c.GLFW_TRUE);
}
