# Gnoll

`gnoll` is a simple library that helps you load your configs from files. It currently supports the following file formats.

- `json`
- `yaml`

`gnoll` is no real substitute for a well thoughtout configuration system but will play nicely with application code.

## Usage

Using `gnoll` is pretty simple.

```zig
// import the library into your file
const gnoll = @import("gnoll");
const Gnoll = gnoll.Gnoll;
const ConfigInfo = gnoll.ConfigInfo; // if you like types
const GnollOptions = gnoll.GnollOptions; // if you like types

// Define your config type
const TestConfig = struct {
    key_0: u32,
    key_1: []const u8,
    key_2: struct {
        key_0: []f32,
    },
};

fn main() !void {
    // Define some filepaths to check for configuration files
    const gnoll_options = GnollOptions{
        .config_infos = &.{
            // if we can't find this file, fallback to the next one etc...
            ConfigInfo{
                .filepath = "./test_data/config_0.json",
                .format = .json,
            },
            ConfigInfo{
                .filepath = "./test_data/config_1.yaml",
                .format = .yaml,
            },
        },
    };

    // Initialize Gnoll with your config Type
    var gnoll = try Gnoll(TestConfig).init(allocator, gnoll_options);
    defer gnoll.deinit(allocator);

    // get values from `gnoll` after initialization
    std.debug.print("key_0 value: {d}\n", .{gnoll.config.key_0});
    std.debug.print("key_2.key_0 value: {any}\n", .{gnoll.config.key_2.key_0});
}
```

## Installation

You can install stdx just like any other zig dependency by editing your `build.zig.zon` file.

```zig
    .dependencies = .{
        .gnoll = .{
            .url = "https://github.com/kobolds-io/gnoll/archive/refs/tags/v0.0.3.tar.gz",
            .hash = "",
        },
    },
```

run zig build --fetch to fetch the dependencies. This will return an error as the has will not match. Copy the new hash and try again.Sometimes zig is helpful and it caches stuff for you in the zig-cache dir. Try deleting that directory if you see some issues.

In your `build.zig` file add the library as a dependency.

```zig
// ...boilerplate

const gnoll_dep = b.dependency("gnoll", .{
    .target = target,
    .optimize = optimize,
});
const gnoll_mod = gnoll_dep.module("gnoll");

exe.root_module.addImport("gnoll", gnoll_mod);
```

## Overview

`gnoll` works by cycling through the passed `GnollOptions` during the `init` function call to find a valid configuration. Once a configuration file exists on the file system, `gnoll` will use the appropriate parser to load into the `gnoll.config` field. Overall, pretty simple but nice and useful.

## Features

| Feature                                        | Implemented |
| ---------------------------------------------- | ----------- |
| `json` support                                 | yes         |
| `yaml` support                                 | yes         |
| `toml` support                                 | no          |
| do not immediately fail on first failed parsed | no          |
