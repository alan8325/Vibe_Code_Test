# Vibe_Code_Test

A Zig project developed with Zig 0.14.0-dev.2577+271452d22.

## Description

This project demonstrates a simple Zig application structure with both a library component (src/root.zig) and an executable (src/main.zig).

## Building and Running

To build and run the project:

```
zig build run
```

To run tests:

```
zig build test
```

## Project Structure

- `src/main.zig` - The entry point for the executable
- `src/root.zig` - The library component with exported functions
- `build.zig` - Build configuration
- `build.zig.zon` - Package definition