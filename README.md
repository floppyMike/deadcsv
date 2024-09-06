# deadcsv
A simple one file zig library providing a csv reader and writer.

## Why dead?
Simply I don't have infinite time to maintain what I write. So I strive for my code to be complete. Meaning I want it to be dead. But this involves it being extremely simple so don't expect many features. But at least it won't be a giant codebase with a dozen dependancies that can break or are insecure.

## How to use it
1. In your `build.zig` add the following: (`exe` is your executable but can also be a library)
    ```zig
    const deadcliPackage = b.dependency("deadcsv", .{
        .target = target,
        .optimize = optimize,
    });
    
    exe.root_module.addImport("deadcsv", deadcliPackage.module("deadcsv"));
    ```
2. Import the library either by used git submodule into `extern` and then adding 
    ```zig
    .deadcsv = .{
       .path = "extern/deadcsv",
    },
    ```
    to the `.dependencies` in `build.zig.zon` or be using zigs [inbuilt system](https://zig.news/edyu/zig-package-manager-wtf-is-zon-558e).
3. Example usage of the library on linux is as follows (with `const dcsv = @import("deadcsv");`):
    ```zig
    const Entry = struct {
        a: []const u8,
        b: []const u8,
        c: []const u8,
    };

    // Reading

    var csvReader = try CSVReader(',', Entry, @TypeOf(reader)).init(alloc, reader, 64, true);
    defer csvReader.deinit();

    while (try csvReader.readEntry()) |entry| {
        // entry is of type Entry
    }

    // Writing

    var csvWriter = try CSVWriter(',', Entry, @TypeOf(writer)).init(writer, true);
    try csvWriter.writeEntry(.{ .a = "1", .b = "2", .c = "3" });
    ```
