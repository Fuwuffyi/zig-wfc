const std = @import("std");
const zigimg = @import("zigimg");
const Color = @import("color.zig").Color;
const Tile = @import("tile.zig").Tile;

pub const TileSet = struct {
    tiles: []Tile,

    pub fn init(allocator: *const std.mem.Allocator, image_file: []const u8, tile_size: u8) !@This() {
        // Read image
        var image = try zigimg.Image.fromFilePath(allocator.*, image_file);
        defer image.deinit();
        // Load the pixels to a local buffer
        var pixels = try allocator.alloc(Color, image.width * image.height);
        defer allocator.free(pixels);
        var color_it = image.iterator();
        var idx: usize = 0;
        while (color_it.next()) |pixel| : (idx += 1) {
            pixels[idx] = .{
                .r = @intFromFloat(pixel.r * 255),
                .g = @intFromFloat(pixel.g * 255),
                .b = @intFromFloat(pixel.b * 255),
            };
        }
        // Initialize the hash map to track unique tiles
        var tile_map = std.AutoHashMap(u64, std.ArrayList(Tile)).init(allocator.*);
        defer {
            var it = tile_map.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit();
            }
            tile_map.deinit();
        }
        // Generate tile colors
        for (0..(image.width * image.height)) |i| {
            // Allocate new colors for the tile
            const colors = try allocator.alloc(Color, tile_size * tile_size);
            errdefer allocator.free(colors);
            // Read the colors from the pixels array
            var colors_idx: usize = 0;
            const y_start = i / image.width;
            const x_start = i % image.width;
            for (0..tile_size) |dy| {
                const y = (y_start + dy) % image.height;
                for (0..tile_size) |dx| {
                    const x = (x_start + dx) % image.width;
                    const pixels_idx: usize = y * image.width + x;
                    colors[colors_idx] = pixels[pixels_idx];
                    colors_idx += 1;
                }
            }
            // Hash colors
            const colors_bytes = std.mem.sliceAsBytes(colors);
            const hash = std.hash.Wyhash.hash(0, colors_bytes);
            // Get or create the entry in the tile_map
            const gop = try tile_map.getOrPut(hash);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayList(Tile).init(allocator.*);
            }
            const list = &gop.value_ptr.*;
            // Check for existing tile with the same colors
            var found = false;
            for (list.items) |*existing_tile| {
                if (Tile.eql(existing_tile.colors, colors)) {
                    existing_tile.freq += 1;
                    allocator.free(colors);
                    found = true;
                    break;
                }
            }
            // Create new element if not existing
            if (!found) {
                try list.append(Tile.init(colors, 1));
            }
        }
        // Collect all unique tiles from the hash map into a single list
        var tiles_list = std.ArrayList(Tile).init(allocator.*);
        defer tiles_list.deinit();
        var it = tile_map.iterator();
        while (it.next()) |entry| {
            try tiles_list.appendSlice(entry.value_ptr.items);
        }
        // Return the owned slice of unique tiles
        return .{ .tiles = try tiles_list.toOwnedSlice() };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        for (self.tiles) |*tile| {
            tile.deinit(allocator);
        }
        allocator.*.free(self.tiles);
    }
};
