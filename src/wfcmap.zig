const std = @import("std");
const Tile = @import("tile.zig").Tile;
const Direction = @import("tile.zig").Direction;
const TileSet = @import("tileset.zig").TileSet;

// TODO: Hardcoded seed...
var random_generator: std.Random.Xoshiro256 = std.Random.DefaultPrng.init(0);
const random: std.Random = random_generator.random();

pub const WfcMap = struct {
    cells: []std.ArrayList(u32),
    width: u32,
    height: u32,
    tileset: *const TileSet,

    pub fn init(allocator: *const std.mem.Allocator, tileset: *const TileSet, width: u32, height: u32) !@This() {
        const cells: []std.ArrayList(u32) = try allocator.alloc(std.ArrayList(u32), width * height);
        for (cells) |*cell| {
            cell.* = std.ArrayList(u32).init(allocator.*);
            for (0..tileset.tiles.len) |i| {
                try cell.append(@intCast(i));
            }
        }
        return .{ .cells = cells, .width = width, .height = height, .tileset = tileset };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        for (self.cells) |*cell| {
            cell.deinit();
        }
        allocator.free(self.cells);
    }

    pub fn step(self: *@This(), allocator: *const std.mem.Allocator) !bool {
        // Get lowest entropy elements
        var lowest_entropy: u32 = std.math.maxInt(u32);
        var lowest_entropy_cells: std.ArrayList(usize) = std.ArrayList(usize).init(allocator.*);
        defer lowest_entropy_cells.deinit();
        for (self.cells, 0..) |*cell, m_idx| {
            // Skip already collapsed elements
            if (cell.items.len <= 1) continue;
            // Calculate entropy
            var cell_entropy: u32 = 0;
            for (cell.items) |c_idx| {
                cell_entropy += self.tileset.tiles[c_idx].freq;
            }
            // Clear list if new entropy record found
            if (cell_entropy < lowest_entropy) {
                lowest_entropy_cells.clearAndFree();
                lowest_entropy = cell_entropy;
            }
            // Add entropy cell if it has same entropy as best
            if (cell_entropy == lowest_entropy) {
                try lowest_entropy_cells.append(m_idx);
            }
        }
        // If the lowest entropy does not change, we have collapsed all cells
        if (lowest_entropy == std.math.maxInt(u32)) return true;
        // Collapse a random lowest entropy element
        const rand_index: usize = lowest_entropy_cells.items[random.int(usize) % lowest_entropy_cells.items.len];
        var rand_cell: *std.ArrayList(u32) = &self.cells[rand_index];
        const random_tile: u32 = rand_cell.items[random.int(usize) % rand_cell.items.len];
        rand_cell.clearAndFree();
        try rand_cell.append(random_tile);
        // Propagate collapse to adjacent tiles
        try self.update_neighbors(allocator, rand_index);
        // Not finished collapsing everything yet
        return false;
    }

    fn update_neighbors(self: *@This(), allocator: *const std.mem.Allocator, starting_index: usize) !void {
        // Create queue of cells to update
        var cell_queue: std.ArrayList(usize) = std.ArrayList(usize).init(allocator.*);
        defer cell_queue.deinit();
        try cell_queue.append(starting_index);
        // Initialization of collapsing structs
        var allowed = std.AutoHashMap(u32, void).init(allocator.*);
        defer allowed.deinit();
        var new_possible = std.ArrayList(u32).init(allocator.*);
        defer new_possible.deinit();
        // Update cells for as long as they are in the queue
        while (cell_queue.popOrNull()) |current_index| {
            // Get current cell data
            const current_cell: *const std.ArrayList(u32) = &self.cells[current_index];
            const current_x: u32 = @as(u32, @intCast(current_index % self.width));
            const current_y: u32 = @as(u32, @intCast(current_index / self.width));
            // Loop over the directions
            const directions = [_]Direction{ .up, .down, .left, .right };
            for (directions) |dir| {
                // Get neighbor cell's position
                var nx: u32 = current_x;
                var ny: u32 = current_y;
                switch (dir) {
                    .up => {
                        if (current_y == 0) continue;
                        ny -= 1;
                    },
                    .down => {
                        if (current_y >= self.height - 1) continue;
                        ny += 1;
                    },
                    .left => {
                        if (current_x == 0) continue;
                        nx -= 1;
                    },
                    .right => {
                        if (current_x >= self.width - 1) continue;
                        nx += 1;
                    },
                }
                // Calculate the neighbor's index
                const neighbor_index: usize = @as(usize, @intCast(ny * self.width + nx));
                const neighbor_cell: *std.ArrayList(u32) = &self.cells[neighbor_index];
                // Skip the neighbor if already collapsed
                if (neighbor_cell.items.len <= 1) continue;
                // Get map of allowed indices based on the direction
                allowed.clearAndFree();
                for (current_cell.items) |tile_idx| {
                    const tile = self.tileset.tiles[tile_idx];
                    const adj_list = tile.adjacencies[@intFromEnum(dir)];
                    for (adj_list.items) |allowed_idx| {
                        try allowed.put(allowed_idx, {});
                    }
                }
                // Create list of possibilities
                new_possible.clearAndFree();
                for (neighbor_cell.items) |tile_idx| {
                    if (allowed.contains(tile_idx)) {
                        try new_possible.append(tile_idx);
                    }
                }
                // Update it only if it changed
                if (new_possible.items.len < neighbor_cell.items.len) {
                    neighbor_cell.clearAndFree();
                    try neighbor_cell.appendSlice(new_possible.items);
                    try cell_queue.append(neighbor_index);
                }
            }
        }
    }
};
