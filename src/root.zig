const std = @import("std");

/// Build up headers out of a given arguments
///
/// Returns:
/// - Header in CSV format
pub fn buildHeader(
    /// CSV Entry
    EntryType: type,
    /// Seperator to use
    comptime sep: u8,
) []const u8 {
    const entry = @typeInfo(EntryType).Struct;

    if (entry.fields.len == 0) {
        @compileError("Must have at least one column.");
    }

    var res = entry.fields[0].name;

    inline for (entry.fields[1..]) |cat| {
        res = res ++ .{sep} ++ cat.name;
    }

    return res;
}

/// Create a CSVReader struct that specializes in parsing a CSV string.
pub fn CSVReader(
    /// Seperator to use
    comptime sep: u8,
    /// Entry type. All fields must have type `[]const u8`
    EntryType: type,
    /// Reader type for reading the csv file
    ReaderType: type,
) type {
    return struct {
        pub const header = buildHeader(EntryType, sep);

        /// Reader type used by CSVReader
        reader: ReaderType,
        /// Internal buffer for storing []u8 which are sliced into the entry
        parseBuf: std.ArrayList(u8),
        /// Current line the reader is on
        line: u64,

        /// Initializes a CSVReader
        pub fn init(
            /// Allocator to use for line buffer
            alloc: std.mem.Allocator,
            /// Reader instance for reading the csv file
            reader: ReaderType,
            // Buffer prealloc size (ex. 64 for 64 bytes)
            prealloc: usize,
            /// If a header is included
            includeHeader: bool,
        ) !@This() {
            var parseBuf = std.ArrayList(u8).init(alloc);
            try parseBuf.ensureTotalCapacity(prealloc);

            var line: usize = 1;

            if (includeHeader) {
                try reader.streamUntilDelimiter(parseBuf.writer(), '\n', null);
                if (!std.mem.eql(u8, parseBuf.items, header)) return error.CSVHeaderMismatch;
                line += 1;
            }

            return .{ .reader = reader, .parseBuf = parseBuf, .line = line };
        }

        /// Deallocates the internal buffer
        pub fn deinit(s: @This()) void {
            s.parseBuf.deinit();
        }

        /// Reads a CSV entry
        ///
        /// Returns:
        /// - A filled out entry of given EntryType
        pub fn readEntry(s: *@This()) !EntryType {
            s.parseBuf.clearRetainingCapacity();
            s.line += 1;

            // Read till line end or eof
            s.reader.streamUntilDelimiter(s.parseBuf.writer(), '\n', null) catch |err| switch (err) {
                error.EndOfStream => {},
                else => |e| return e,
            };

            const entryInfo = @typeInfo(EntryType).Struct;
            const categories = entryInfo.fields;

            var offsets: [categories.len]usize = undefined;
            offsets[offsets.len - 1] = s.parseBuf.items.len;

            // Iterate through buffer and find all delimiters
            var offsetIter: usize = 0;
            var bufferIter: usize = 0;
            while (bufferIter < s.parseBuf.items.len and offsetIter < offsets.len) : (bufferIter += 1) {
                const c = s.parseBuf.items[bufferIter];
                if (c == sep) {
                    offsets[offsetIter] = bufferIter;
                    offsetIter += 1;
                }
            }

            // If too many delimiters (bufferIter too small) or too little delimiters (offsetIter too small)
            if (bufferIter != s.parseBuf.items.len or offsetIter != offsets.len - 1) {
                return error.MismatchNumberOfEntries;
            }

            var e: EntryType = undefined;

            var prevOffset: usize = 0;
            inline for (offsets, categories) |offset, f| {
                @field(e, f.name) = s.parseBuf.items[prevOffset..offset];
                prevOffset = offset + 1; // Skip delimiter
            }

            return e;
        }
    };
}

test CSVReader {
    {
        var buffer = std.io.fixedBufferStream("a,b\n1,2\n,\n");
        const bufferReader = buffer.reader();

        const Entry = struct {
            a: []const u8,
            b: []const u8,
        };

        var csvReader = try CSVReader(',', Entry, @TypeOf(bufferReader)).init(std.testing.allocator, bufferReader, 64, true);
        defer csvReader.deinit();

        try std.testing.expectEqualDeep(Entry{ .a = "1", .b = "2" }, try csvReader.readEntry());
        try std.testing.expectEqualDeep(Entry{ .a = "", .b = "" }, try csvReader.readEntry());
    }
}

/// Create a CSVWriter struct that specializes in writing a CSV string.
pub fn CSVWriter(
    /// Seperator to use
    comptime sep: u8,
    /// Entry type. All fields must have type `[]const u8`
    EntryType: type,
    /// Writer type for writing the csv
    WriterType: type,
) type {
    return struct {
        pub const header = buildHeader(EntryType, sep);

        writer: WriterType,
        line: u64,

        /// Initializes a CSVWriter
        pub fn init(
            /// Writer instance for writing the csv
            writer: WriterType,
            /// If a header is included
            includeHeader: bool,
        ) !@This() {
            var line: usize = 1;

            if (includeHeader) {
                try writer.writeAll(header);
                try writer.writeByte('\n');
                line += 1;
            }

            return .{ .writer = writer, .line = line };
        }

        /// Writes a CSV entry
        pub fn writeEntry(
            s: *@This(),
            /// Entry to write
            row: EntryType,
        ) !void {
            const rowInfo = @typeInfo(EntryType).Struct;
            const rowFields = rowInfo.fields;

            inline for (rowFields[0..(rowFields.len - 1)]) |field| {
                try s.writer.writeAll(@field(row, field.name));
                try s.writer.writeByte(sep);
            }

            try s.writer.writeAll(@field(row, rowFields[rowFields.len - 1].name));
            try s.writer.writeByte('\n');

            s.line += 1;
        }
    };
}

test CSVWriter {
    {
        var buffer: [64]u8 = undefined;
        var bufferStream = std.io.fixedBufferStream(&buffer);
        const bufferWriter = bufferStream.writer();

        const Entry = struct {
            a: []const u8,
            b: []const u8,
        };

        var csvWriter = try CSVWriter(',', Entry, @TypeOf(bufferWriter)).init(bufferWriter, true);
        try csvWriter.writeEntry(.{ .a = "1", .b = "2" });
        try csvWriter.writeEntry(.{ .a = "", .b = "" });

        try std.testing.expectEqualDeep("a,b\n1,2\n,\n", bufferStream.getWritten());
    }
}
