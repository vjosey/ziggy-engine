const std = @import("std");

pub const MainTab = enum {
    design,
    code,
};

pub const PanelKind = enum {
    hierarchy,
    properties,
    codeFiles,
    codeOutline,
};

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub const PanelState = struct {
    kind: PanelKind,
    tab: MainTab,
    rect: Rect,
    visible: bool,
    movable: bool,
    resizable: bool,
    z_index: i32,
};

pub const StudioState = struct {
    panels: []PanelState,
    active_tab: MainTab,

    // drag state
    dragging_panel: ?usize,
    drag_offset_x: f32,
    drag_offset_y: f32,
};

pub fn initStudioState(
    allocator: std.mem.Allocator,
    viewport: Rect,
) !StudioState {
    var panels = try allocator.alloc(PanelState, 4);

    const top_bar_height: f32 = 56;
    const margin: f32 = 20;

    // Hierarchy panel (Design tab, left floating)
    panels[0] = PanelState{
        .kind = .hierarchy,
        .tab = .design,
        .rect = Rect{
            .x = margin,
            .y = margin + top_bar_height,
            .w = 280,
            .h = viewport.h - (margin * 2) - top_bar_height,
        },
        .visible = true,
        .movable = true,
        .resizable = true,
        .z_index = 10,
    };

    // Properties panel (Design tab, right floating)
    panels[1] = PanelState{
        .kind = .properties,
        .tab = .design,
        .rect = Rect{
            .x = viewport.w - margin - 320,
            .y = margin + top_bar_height,
            .w = 320,
            .h = viewport.h - (margin * 2) - top_bar_height,
        },
        .visible = true,
        .movable = true,
        .resizable = true,
        .z_index = 10,
    };

    // Code files sidebar (Code tab, left)
    panels[2] = PanelState{
        .kind = .codeFiles,
        .tab = .code,
        .rect = Rect{
            .x = margin,
            .y = margin + top_bar_height,
            .w = 260,
            .h = viewport.h - (margin * 2) - top_bar_height,
        },
        .visible = true,
        .movable = false, // pinned for now
        .resizable = true,
        .z_index = 5,
    };

    // Code outline sidebar (Code tab, right)
    panels[3] = PanelState{
        .kind = .codeOutline,
        .tab = .code,
        .rect = Rect{
            .x = viewport.w - margin - 220,
            .y = margin + top_bar_height,
            .w = 220,
            .h = viewport.h - (margin * 2) - top_bar_height,
        },
        .visible = true,
        .movable = false,
        .resizable = true,
        .z_index = 5,
    };

    return StudioState{
        .panels = panels,
        .active_tab = .design,
        .dragging_panel = null,
        .drag_offset_x = 0,
        .drag_offset_y = 0,
    };
}

/// Call this when the window resizes to re-layout panels in a simple way.
/// (Later we can make this preserve user positions.)
pub fn relayoutOnResize(
    studio: *StudioState,
    viewport: Rect,
) void {
    const top_bar_height: f32 = 56;
    const margin: f32 = 20;

    for (studio.panels) |*p| {
        switch (p.kind) {
            .hierarchy => {
                p.rect = Rect{
                    .x = margin,
                    .y = margin + top_bar_height,
                    .w = 280,
                    .h = viewport.h - (margin * 2) - top_bar_height,
                };
            },
            .properties => {
                p.rect = Rect{
                    .x = viewport.w - margin - 320,
                    .y = margin + top_bar_height,
                    .w = 320,
                    .h = viewport.h - (margin * 2) - top_bar_height,
                };
            },
            .codeFiles => {
                p.rect = Rect{
                    .x = margin,
                    .y = margin + top_bar_height,
                    .w = 260,
                    .h = viewport.h - (margin * 2) - top_bar_height,
                };
            },
            .codeOutline => {
                p.rect = Rect{
                    .x = viewport.w - margin - 220,
                    .y = margin + top_bar_height,
                    .w = 220,
                    .h = viewport.h - (margin * 2) - top_bar_height,
                };
            },
        }
    }
}

/// Switch between Design/Code main tabs (e.g. when user clicks your top bar).
pub fn setActiveTab(studio: *StudioState, tab: MainTab) void {
    studio.active_tab = tab;
}

/// Mouse handling for dragging panels.
/// Call this from your GLFW mouse callbacks.
pub fn handleMouseDown(
    studio: *StudioState,
    mouse_x: f32,
    mouse_y: f32,
) void {
    // find top-most movable panel whose header was clicked
    var best_index: ?usize = null;
    var best_z: i32 = -2147483648;

    var i: usize = 0;
    while (i < studio.panels.len) : (i += 1) {
        const p = &studio.panels[i];
        if (!p.visible or !p.movable or p.tab != studio.active_tab) continue;

        if (isInHeader(p.*, mouse_x, mouse_y)) {
            if (p.z_index >= best_z) {
                best_z = p.z_index;
                best_index = i;
            }
        }
    }

    if (best_index) |idx| {
        var p = &studio.panels[idx];

        studio.dragging_panel = idx;
        studio.drag_offset_x = mouse_x - p.rect.x;
        studio.drag_offset_y = mouse_y - p.rect.y;

        // bring to front
        var max_z: i32 = p.z_index;
        for (studio.panels) |other| {
            if (other.z_index > max_z) max_z = other.z_index;
        }
        p.z_index = max_z + 1;
    }
}

pub fn handleMouseMove(
    studio: *StudioState,
    mouse_x: f32,
    mouse_y: f32,
    mouse_down: bool,
) void {
    if (!mouse_down) return;

    if (studio.dragging_panel) |idx| {
        var p = &studio.panels[idx];
        p.rect.x = mouse_x - studio.drag_offset_x;
        p.rect.y = mouse_y - studio.drag_offset_y;
    }
}

pub fn handleMouseUp(studio: *StudioState) void {
    studio.dragging_panel = null;
}

fn isInHeader(p: PanelState, x: f32, y: f32) bool {
    const header_height: f32 = 28.0;
    return x >= p.rect.x and x <= (p.rect.x + p.rect.w) and
        y >= p.rect.y and y <= (p.rect.y + header_height);
}
