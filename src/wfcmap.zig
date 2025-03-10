const std = @import("std");
const Tile = @import("tile.zig").Tile;
const Color = @import("color.zig").Color;
const Direction = @import("tile.zig").Direction;
const TileSet = @import("tileset.zig").TileSet;

pub const WfcError = error{Contradiction};

// TODO: Hardcoded seed...
var random_generator: std.Random.Xoshiro256 = std.Random.DefaultPrng.init(0);
const random: std.Random = random_generator.random();

pub const WfcMap = struct {
    const Pair = std.meta.Tuple(&.{ i64, i64 });
    const Cell = struct {
        possible: std.DynamicBitSet,
        entropy: u32,
    };

    cells: [][]Cell,
    width: u32,
    height: u32,
    tileset: *const TileSet,

    pub fn init(allocator: std.mem.Allocator, tileset: *const TileSet, width: u32, height: u32) !@This() {
        // Create the map
        var map: WfcMap = .{ .cells = try allocator.alloc([]Cell, height), .width = width, .height = height, .tileset = tileset };
        const num_tiles: usize = tileset.tiles.len;
        for (map.cells) |*row| {
            row.* = try allocator.alloc(Cell, width);
            for (row.*) |*cell| {
                cell.* = .{
                    .possible = try std.DynamicBitSet.initEmpty(allocator, num_tiles),
                    .entropy = 0,
                };
            }
        }
        map.reset();
        return map;
    }

    pub fn deinit(self: *const @This(), allocator: std.mem.Allocator) void {
        for (self.cells) |*row| {
            defer allocator.free(row.*);
            for (row.*) |*cell| {
                cell.possible.deinit();
            }
        }
        allocator.free(self.cells);
    }

    pub fn reset(self: *@This()) void {
        // Reset all cells
        const num_tiles: usize = self.tileset.tiles.len;
        for (self.cells) |*row| {
            for (row.*) |*cell| {
                cell.possible.setRangeValue(.{ .start = 0, .end = num_tiles }, true);
                cell.*.entropy = calculate_cell_entropy(self.tileset, cell.possible);
            }
        }
    }

    pub fn get_color_at(self: *const @This(), x: usize, y: usize) Color {
        const cell = &self.cells[y][x];
        var sum_r: u32 = 0;
        var sum_g: u32 = 0;
        var sum_b: u32 = 0;
        var entropy: u32 = 0;
        var cell_it = cell.possible.iterator(.{});
        while (cell_it.next()) |tile_idx| {
            const tile: Tile = self.tileset.tiles[tile_idx];
            const w: usize = tile.colors.len;
            const h: usize = tile.colors[0].len;
            const clr: *const Color = tile.get_color_at(w / 2, h / 2);
            sum_r += clr.r * tile.freq;
            sum_g += clr.g * tile.freq;
            sum_b += clr.b * tile.freq;
            entropy += tile.freq;
        }
        return .{ .r = @intCast(sum_r / entropy), .g = @intCast(sum_g / entropy), .b = @intCast(sum_b / entropy) };
    }

    pub fn step(self: *@This(), allocator: std.mem.Allocator) !bool {
        // Get lowest entropy elements
        var lowest_entropy: u32 = std.math.maxInt(u32);
        var lowest_entropy_cells: std.ArrayList(Pair) = std.ArrayList(Pair).init(allocator);
        defer lowest_entropy_cells.deinit();
        for (self.cells, 0..) |*row, row_idx| {
            for (row.*, 0..) |*cell, col_idx| {
                const m_idx: Pair = .{ @intCast(row_idx), @intCast(col_idx) };
                // Skip already collapsed elements
                if (cell.possible.count() <= 1) continue;
                // Clear list if new entropy record found
                if (cell.entropy < lowest_entropy) {
                    lowest_entropy_cells.clearAndFree();
                    lowest_entropy = cell.entropy;
                }
                // Add entropy cell if it has same entropy as best
                if (cell.entropy == lowest_entropy) {
                    try lowest_entropy_cells.append(m_idx);
                }
            }
        }
        // If the lowest entropy does not change, we have collapsed all cells
        if (lowest_entropy == std.math.maxInt(u32)) return true;
        // Collapse a random lowest entropy element
        const rand_index: Pair = lowest_entropy_cells.items[random.int(usize) % lowest_entropy_cells.items.len];
        var rand_cell: *Cell = &self.cells[@intCast(rand_index.@"0")][@intCast(rand_index.@"1")];
        const random_tile: u32 = select_tile_by_frequency(self.tileset, &rand_cell.possible);
        rand_cell.possible.deinit();
        rand_cell.possible = try std.DynamicBitSet.initEmpty(allocator, self.tileset.tiles.len);
        rand_cell.possible.set(random_tile);
        // Propagate collapse to adjacent tiles
        try self.update_neighbors(allocator, &rand_index);
        // Not finished collapsing everything yet
        return false;
    }

    fn calculate_cell_entropy(tileset: *const TileSet, possible: std.DynamicBitSet) u32 {
        var sum: u32 = 0;
        var it = possible.iterator(.{});
        while (it.next()) |tile| {
            sum += tileset.tiles[tile].freq;
        }
        return sum;
    }

    fn select_tile_by_frequency(tileset: *const TileSet, possible: *const std.DynamicBitSet) u32 {
        var total: u32 = 0;
        var it = possible.iterator(.{});
        while (it.next()) |tile| {
            total += tileset.tiles[tile].freq;
        }
        var rand = random.int(u32) % total;
        it = possible.iterator(.{});
        while (it.next()) |tile| {
            const freq = tileset.tiles[tile].freq;
            if (rand < freq) return @intCast(tile);
            rand -= freq;
        }
        unreachable;
    }

    fn update_neighbors(self: *@This(), allocator: std.mem.Allocator, starting_index: *const Pair) !void {
        // Create queue of cells to update
        var cell_queue: std.ArrayList(Pair) = std.ArrayList(Pair).init(allocator);
        defer cell_queue.deinit();
        try cell_queue.append(starting_index.*);
        // Update cells for as long as they are in the queue
        while (cell_queue.popOrNull()) |current_index| {
            // Get current cell data
            const current_cell: *const Cell = &self.cells[@intCast(current_index.@"0")][@intCast(current_index.@"1")];
            // Loop over the directions
            for (std.enums.values(Direction)) |dir| {
                // Get neighbor cell's position
                const neighbor_position: Pair = switch (dir) {
                    .up => .{ .@"0" = current_index.@"0" - 1, .@"1" = current_index.@"1" },
                    .down => .{ .@"0" = current_index.@"0" + 1, .@"1" = current_index.@"1" },
                    .left => .{ .@"0" = current_index.@"0", .@"1" = current_index.@"1" - 1 },
                    .right => .{ .@"0" = current_index.@"0", .@"1" = current_index.@"1" + 1 },
                };
                // Skip if out of bounds
                if (neighbor_position.@"0" < 0 or neighbor_position.@"0" >= @as(usize, @intCast(self.height))) continue;
                if (neighbor_position.@"1" < 0 or neighbor_position.@"1" >= @as(usize, @intCast(self.width))) continue;
                // Calculate the neighbor's index
                const neighbor_cell: *Cell = &self.cells[@intCast(neighbor_position.@"0")][@intCast(neighbor_position.@"1")];
                // Skip the neighbor if already collapsed
                if (neighbor_cell.possible.count() <= 1) continue;
                // Get map of allowed indices based on the direction
                var allowed = try std.DynamicBitSet.initEmpty(allocator, self.tileset.tiles.len);
                defer allowed.deinit();
                var it = current_cell.possible.iterator(.{});
                while (it.next()) |tile| {
                    const adj = &self.tileset.tiles[tile].adjacencies[@intFromEnum(dir)];
                    allowed.setUnion(adj.*);
                }
                const prev_count = neighbor_cell.possible.count();
                neighbor_cell.possible.setIntersection(allowed);
                const new_count = neighbor_cell.possible.count();
                if (new_count == 0) return error.Contradiction;
                if (new_count < prev_count) {
                    neighbor_cell.entropy = calculate_cell_entropy(self.tileset, neighbor_cell.possible);
                    try cell_queue.append(neighbor_position);
                }
            }
        }
    }
};
