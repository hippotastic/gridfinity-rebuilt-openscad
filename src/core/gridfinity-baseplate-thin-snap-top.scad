// Thin snap-together top connector cutout geometry.

module cutter_snap_together(gx, gy, size = l_grid) {
    assert(gx >= 1);
    assert(gy >= 1);

    if (gx > 1) {
        for (x = [1:gx-1]) {
            translate([(-gx/2 + x) * size, -gy * size/2, 0])
            cutter_snap_connector_edge();

            translate([(-gx/2 + x) * size, gy * size/2, 0])
            rotate([0, 0, 180])
            cutter_snap_connector_edge();
        }
    }

    if (gy > 1) {
        for (y = [1:gy-1]) {
            translate([-gx * size/2, (-gy/2 + y) * size, 0])
            rotate([0, 0, -90])
            cutter_snap_connector_edge();

            translate([gx * size/2, (-gy/2 + y) * size, 0])
            rotate([0, 0, 90])
            cutter_snap_connector_edge();
        }
    }
}

module cutter_snap_connector_edge() {
    // Based on the snap connector from this URL:
    // https://www.printables.com/model/430144-gridfinity-base-with-snap-connectors
    // The 2D profile below matches the reference connector cutout before it is rotated into
    // place on each outside edge. In this local sketch, X goes inward from the edge and Y is
    // height above the bottom of the baseplate.
    slot_width = 4.2 + 2*TOLLERANCE;

    floor_z = 0.95;
    top_cap_z = floor_z + 1.85;
    top_z = max(BASEPLATE_HEIGHT - top_cutoff, top_cap_z) + TOLLERANCE;

    // Extend the cutter mouth past the nominal edge so smaller outer_margin values do not leave
    // a blocking wall in front of the connector opening.
    entry_x = -0.10;
    cutout_depth = 2.65;

    // Unfilleted sketch points from the reference profile. The two rounded transitions are
    // generated from these corners below instead of storing arc centers and tangent angles.
    lower_step_x = 0.90;
    lower_step_top = [lower_step_x, floor_z + 0.555];
    inner_corner = [1.65, floor_z + 0.92];
    top_corner = [0.765, top_cap_z];

    arc_steps = 12;
    bottom_fillet = fillet_arc_points(
        lower_step_top,
        inner_corner,
        top_corner,
        0.60,
        arc_steps
    );
    top_fillet = fillet_arc_points(
        inner_corner,
        top_corner,
        [0.10, top_cap_z],
        0.15,
        6
    );

    // Local 2D cutter profile, before rotation/extrusion. The the closed outline is subtracted
    // from the baseplate.
    //
    //     Y
    //     ^
    //     |   +----------------------+  top_z
    //     |   |                      |
    //     |   +_______               |  top_cap_z
    //     |            \             |  top_fillet, R0.15
    //     |             \            |
    //     |              \           |
    //     |               )          |  bottom_fillet, R0.60
    //     |             .'           |
    //     |          .'              |  lower_step_top
    //     |          |               |
    //     |          +---------------+  floor_z
    //     |
    //     +----------------------------------------------> X inward
    //         entry_x                cutout_depth
    //
    // The connector-facing opening starts at x=0.10; entry_x only clears material in front
    // of that opening when outer_margin is smaller than 0.10 mm.
    // The polygon walks clockwise around the cutter cross-section.
    profile = concat([
        [entry_x, top_cap_z],
        [entry_x, top_z],
        [cutout_depth, top_z],
        [cutout_depth, floor_z],
        [lower_step_x, floor_z],
        lower_step_top
    ], bottom_fillet, top_fillet, [
        [entry_x, top_cap_z]
    ]);

    translate([-slot_width/2, 0, 0])
    rotate([90, 0, 90])
    linear_extrude(slot_width)
    polygon(profile);
}
