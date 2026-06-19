/* [Thin Snap Together Top Settings] */
thin_snap_top_friction_fit = 0.10; // [0:0.05:0.30]
thin_snap_top_z_axis_fit = 0.20; // [0:0.05:0.40]
thin_snap_top_snap_flex = 0.30; // [0:0.05:0.60]
thin_snap_top_corner_chamfer_top = 2.20; // [0:0.05:3.50]
thin_snap_top_corner_chamfer_foot = 1.80; // [0:0.05:3.50]
thin_snap_top_connector_foot_chamfer = 0.20; // [0:0.05:1.00]

// Thin snap-together top connector geometry.
//
// Local coordinate convention in this file:
// - X is the 2D profile width.
// - Y is the 2D profile height, from connector feet toward the deck.
// - Z is the extrusion depth through the connector/cutout.
//
// The baseplate uses a different orientation, so edge instances pass through
// _thin_snap_top_connector_edge_transform() before they are used as cutters.

// Baseplate cutter entry point. One negative cutout is placed on every internal
// grid edge: horizontal edges first, then vertical edges rotated into place.
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

// Adapter used by the baseplate difference(). It intentionally exposes only the
// negative cutout; the printed connector body is rendered through debug/preview
// helpers or as a standalone connector.
module cutter_snap_connector_edge() {
    _thin_snap_top_connector_edge(cutout=true);
}

// Places either the negative cutout or the positive connector on one baseplate
// edge using the shared edge transform below.
module _thin_snap_top_connector_edge(cutout=false) {
    assert(is_bool(cutout));

    _thin_snap_top_connector_edge_transform()
    _thin_snap_top_connector(cutout=cutout);
}

// Local geometry dispatcher. The cutout and printed connector share the same
// coordinate system so they can be overlaid and compared directly in preview.
module _thin_snap_top_connector(cutout=false) {
    assert(is_bool(cutout));

    if (cutout) {
        _thin_snap_top_cutout_body();
    } else {
        _thin_snap_top_snap_connector_body();
    }
}

// Standalone display wrapper for previews. Rendering only the translucent cutout
// in preview avoids OpenCSG artifacts leaking through its own coplanar faces.
module _thin_snap_top_connector_display(cutout=false) {
    assert(is_bool(cutout));

    if ($preview && cutout) {
        // Keep the transparent standalone cutout from leaking preview artifacts through itself.
        render(convexity=4)
        _thin_snap_top_connector(cutout=cutout);
    } else {
        _thin_snap_top_connector(cutout=cutout);
    }
}

// Convert local connector coordinates onto a baseplate edge. The transform maps
// local profile height to baseplate Z and local extrusion depth along the edge.
module _thin_snap_top_connector_edge_transform() {
    rotate([-270, 0, 0])
    rotate([0, -90, 0])
    translate(_thin_snap_top_connector_edge_translation() * -1)
    children();
}

// The cutout body deliberately extends a small tolerance above the nominal
// baseplate top so boolean subtraction cannot leave a thin skin behind.
function _thin_snap_top_connector_edge_translation() = [
    0,
    _thin_snap_top_sketch_top_z() - (BASEPLATE_HEIGHT + TOLLERANCE),
    0
];

// When connector and cutout are both shown as standalone parts, separate them
// horizontally. In the overlay preview both translations resolve to zero.
function _thin_snap_top_connector_standalone_translation() =
    render_connector && render_cutout ? [-_thin_snap_top_standalone_spacing(), 0, 0] : [0, 0, 0];
function _thin_snap_top_cutout_standalone_translation() =
    render_connector && render_cutout ? [_thin_snap_top_standalone_spacing(), 0, 0] : [0, 0, 0];
function _thin_snap_top_standalone_spacing() =
    max(_thin_snap_top_cutout_width(), _thin_snap_top_connector_width()) + 3.00;

// Preview helper: show the printed connector in the same position it would take
// inside the baseplate, so fit and top-cutoff alignment can be inspected.
module _thin_snap_top_debug_connector_in_baseplate(gx, gy, size = l_grid) {
    assert(gx >= 1);
    assert(gy >= 1);

    if (gx > 1) {
        translate(_thin_snap_top_debug_connector_origin(gx, gy, size))
        _thin_snap_top_connector_edge(cutout=false);
    } else if (gy > 1) {
        translate(_thin_snap_top_debug_connector_origin(gx, gy, size))
        rotate([0, 0, -90])
        _thin_snap_top_connector_edge(cutout=false);
    }
}

// Preview helper: cuts away most of the baseplate/connector so the internal
// snap geometry remains visible while debugging an assembled baseplate.
module _thin_snap_top_debug_section_cutter(gx, gy, size = l_grid) {
    assert(gx >= 1);
    assert(gy >= 1);

    extent = _thin_snap_top_debug_section_extent(gx, gy, size);
    origin = _thin_snap_top_debug_connector_origin(gx, gy, size);

    if (gx > 1) {
        translate([origin.x - extent, -extent/2, origin.z - extent/2])
        cube([extent, extent, extent]);
    } else if (gy > 1) {
        translate([-extent/2, origin.y - extent, origin.z - extent/2])
        cube([extent, extent, extent]);
    }
}

function _thin_snap_top_debug_connector_origin(gx, gy, size) =
    (gx > 1
        ? [(-gx/2 + 1) * size, -gy * size/2, 0]
        : [-gx * size/2, (-gy/2 + 1) * size, 0])
    + [0, 0, _thin_snap_top_bottom_padding_delta()];

function _thin_snap_top_debug_section_extent(gx, gy, size) =
    max(gx, gy) * size + 2 * BASEPLATE_HEIGHT + 20;

// Debug connector overlays are shown after bottom padding has been applied, so
// they need the same vertical padding delta as the final baseplate.
function _thin_snap_top_bottom_padding_delta() =
    bottom_padding - (BASEPLATE_HEIGHT - _BASEPLATE_PROFILE[3].y);

// Positive printed connector. It starts as the fitted 2D profile extrusion and
// then subtracts the four cutout-referenced deck chamfers.
module _thin_snap_top_snap_connector_body() {
    difference() {
        _thin_snap_top_body(cutout=false);
        _thin_snap_top_corner_chamfers(
            top_chamfer=thin_snap_top_corner_chamfer_top,
            foot_chamfer=thin_snap_top_corner_chamfer_foot
        );
    }
}

// Negative baseplate cutout. This stays rectangular at the deck so it can define
// the reference corners used by the printed connector chamfer cutters.
module _thin_snap_top_cutout_body() {
    _thin_snap_top_body(cutout=true);
}

// Shared extrusion pipeline for the cutout and connector. All fit logic lives in
// the point functions below; this module only validates the resulting dimensions
// and extrudes the selected 2D profile through the connector depth.
module _thin_snap_top_body(cutout=false) {
    assert(is_bool(cutout));
    assert(thin_snap_top_friction_fit >= 0);
    assert(thin_snap_top_z_axis_fit >= 0);
    assert(thin_snap_top_snap_flex >= 0);
    assert(thin_snap_top_corner_chamfer_top >= 0);
    assert(thin_snap_top_corner_chamfer_foot >= 0);
    assert(thin_snap_top_connector_foot_chamfer >= 0);
    assert(_thin_snap_top_body_depth(cutout) > 0);

    if (!cutout) {
        assert(_thin_snap_top_connector_outer_side_x() < _thin_snap_top_connector_opening_snap_x(),
            "thin_snap_top_snap_flex and thin_snap_top_friction_fit leave no top-snap connector leg material.");
        assert(_thin_snap_top_connector_opening_lower_z() < _thin_snap_top_connector_opening_top_z(),
            "thin_snap_top_z_axis_fit is too large for the top-snap connector.");
        assert(_thin_snap_top_connector_opening_top_z() < _thin_snap_top_connector_top_z(),
            "top_cutoff is too large for the top-snap connector opening.");
        assert(thin_snap_top_connector_foot_chamfer < min(
                _thin_snap_top_connector_foot_width(),
                _thin_snap_top_connector_top_z() - _thin_snap_top_connector_bottom_z()
            ),
            "thin_snap_top_connector_foot_chamfer is too large for the top-snap connector foot.");
    }

    linear_extrude(_thin_snap_top_body_depth(cutout), center=true, convexity=8)
    _thin_snap_top_profile_2d(cutout=cutout);
}

// Place one deck-corner cutter at each cutout corner. The cutter is referenced
// to the larger cutout, not to the already-shrunk connector, so the printed part
// is chamfered relative to the same envelope that the baseplate removes.
module _thin_snap_top_corner_chamfers(top_chamfer=0, foot_chamfer=0) {
    assert(is_num(top_chamfer) && top_chamfer >= 0);
    assert(is_num(foot_chamfer) && foot_chamfer >= 0);

    if (top_chamfer > 0 && foot_chamfer > 0) {
        corner_x = _thin_snap_top_sketch_mirror_x();
        top_z = _thin_snap_top_sketch_top_z();
        bottom_z = _thin_snap_top_cutout_bottom_z();
        half_depth = _thin_snap_top_cutout_depth() / 2;

        assert(top_chamfer < min(corner_x, _thin_snap_top_cutout_depth()) && foot_chamfer < top_z - bottom_z,
            "thin_snap_top_corner_chamfer_top or thin_snap_top_corner_chamfer_foot is too large for the top-snap cutout.");

        for (x_side = [-1, 1]) {
            for (z_side = [-1, 1]) {
                translate([x_side * corner_x, top_z, z_side * half_depth])
                scale([x_side, 1, z_side])
                _thin_snap_top_corner_chamfer_cutter(top_chamfer, foot_chamfer);
            }
        }
    }
}

// Asymmetric tetrahedron used for the deck chamfer. The two top-plane edges use
// top_chamfer and the downward edge uses foot_chamfer, matching the steeper
// side slope of the Gridfinity cutout.
module _thin_snap_top_corner_chamfer_cutter(top_chamfer, foot_chamfer) {
    assert(is_num(top_chamfer) && top_chamfer > 0);
    assert(is_num(foot_chamfer) && foot_chamfer > 0);

    overlap = TOLLERANCE;

    // Apex is a cutout deck corner. The two top-plane edges are longer than the
    // edge toward the connector foot; the apex extends outward to avoid preview
    // artifacts from cutter faces lying exactly on the cutout boundary.
    polyhedron(
        points=[
            [overlap, overlap, overlap],
            [-top_chamfer, 0, 0],
            [0, -foot_chamfer, 0],
            [0, 0, -top_chamfer]
        ],
        faces=[
            [0, 2, 1],
            [0, 1, 3],
            [0, 3, 2],
            [1, 2, 3]
        ],
        convexity=2
    );
}

// 2D profile selector. Cutout and connector profiles intentionally differ:
// the cutout is the baseplate negative, while the connector is the printable
// positive part after fit offsets and small foot chamfers.
module _thin_snap_top_profile_2d(cutout=false) {
    assert(is_bool(cutout));

    if (cutout) {
        _thin_snap_top_cutout_profile_2d();
    } else {
        _thin_snap_top_connector_profile_2d();
    }
}

// Negative cutout profile: a full outer rectangle minus the snap opening.
module _thin_snap_top_cutout_profile_2d() {
    difference() {
        polygon(_thin_snap_top_centered_points(_thin_snap_top_cutout_outer_points()));
        polygon(_thin_snap_top_centered_points(_thin_snap_top_cutout_opening_points()));
    }
}

// Positive connector profile: the fitted outer shell minus the fitted opening,
// followed by four small 2D chamfers on the bottom foot corners.
module _thin_snap_top_connector_profile_2d() {
    difference() {
        difference() {
            polygon(_thin_snap_top_centered_points(_thin_snap_top_connector_outer_points()));
            polygon(_thin_snap_top_centered_points(_thin_snap_top_connector_opening_points()));
        }
        _thin_snap_top_connector_foot_chamfers_2d(thin_snap_top_connector_foot_chamfer);
    }
}

// Chamfers off the four lower connector-foot corners before extrusion. Each cutter
// overlaps by TOLLERANCE outside the profile to avoid coincident preview edges.
module _thin_snap_top_connector_foot_chamfers_2d(chamfer=0) {
    assert(is_num(chamfer) && chamfer >= 0);

    if (chamfer > 0) {
        side_x = _thin_snap_top_connector_outer_side_x();
        right_x = _thin_snap_top_sketch_width() - side_x;
        inner_left_x = _thin_snap_top_sketch_mirror_x() - _thin_snap_top_connector_opening_half_width();
        inner_right_x = _thin_snap_top_sketch_mirror_x() + _thin_snap_top_connector_opening_half_width();
        bottom_z = _thin_snap_top_connector_bottom_z();
        overlap = TOLLERANCE;

        polygon(_thin_snap_top_centered_points([
            [side_x - overlap, bottom_z - overlap],
            [side_x + chamfer, bottom_z],
            [side_x, bottom_z + chamfer]
        ]));

        polygon(_thin_snap_top_centered_points([
            [right_x + overlap, bottom_z - overlap],
            [right_x, bottom_z + chamfer],
            [right_x - chamfer, bottom_z]
        ]));

        polygon(_thin_snap_top_centered_points([
            [inner_left_x + overlap, bottom_z - overlap],
            [inner_left_x, bottom_z + chamfer],
            [inner_left_x - chamfer, bottom_z]
        ]));

        polygon(_thin_snap_top_centered_points([
            [inner_right_x - overlap, bottom_z - overlap],
            [inner_right_x + chamfer, bottom_z],
            [inner_right_x, bottom_z + chamfer]
        ]));
    }
}

// Cutout outer envelope. The deck corners from this rectangle are also the
// reference points for the printed connector's 3D deck chamfers.
function _thin_snap_top_cutout_outer_points() = [
    [0, _thin_snap_top_cutout_bottom_z()],
    [_thin_snap_top_sketch_width(), _thin_snap_top_cutout_bottom_z()],
    [_thin_snap_top_sketch_width(), _thin_snap_top_sketch_top_z()],
    [0, _thin_snap_top_sketch_top_z()]
];

// Fitted connector outer envelope. Its top follows top_cutoff, while the bottom
// still follows z-axis fit so insertion clearance is preserved at the feet.
function _thin_snap_top_connector_outer_points() =
    let(
        side_x = _thin_snap_top_connector_outer_side_x(),
        right_x = _thin_snap_top_sketch_width() - side_x,
        bottom_z = _thin_snap_top_connector_bottom_z(),
        top_z = _thin_snap_top_connector_top_z()
    )
    [
        [side_x, bottom_z],
        [right_x, bottom_z],
        [right_x, top_z],
        [side_x, top_z]
    ];

// Cutout snap opening. It is intentionally based on fixed cutout dimensions so
// friction and fit are handled by shrinking/expanding the connector instead.
function _thin_snap_top_cutout_opening_points() =
    _thin_snap_top_mirrored_opening_points(
        _thin_snap_top_opening_left_points(
            bottom_half_width=_thin_snap_top_cutout_opening_half_width(),
            lower_snap_half_width=_thin_snap_top_cutout_opening_snap_half_width(),
            upper_snap_half_width=_thin_snap_top_cutout_opening_snap_half_width(),
            top_half_width=_thin_snap_top_cutout_opening_half_width(),
            lower_z=_thin_snap_top_cutout_opening_lower_z(),
            top_z=_thin_snap_top_cutout_opening_top_z(),
            bottom_z=_thin_snap_top_cutout_bottom_z() - TOLLERANCE
        )
    );

// Printed connector snap opening. Fit parameters move this opening relative to
// the cutout so the printed connector has friction and z-axis clearance.
function _thin_snap_top_connector_opening_points() =
    _thin_snap_top_mirrored_opening_points(
        _thin_snap_top_opening_left_points(
            bottom_half_width=_thin_snap_top_connector_opening_half_width(),
            lower_snap_half_width=_thin_snap_top_connector_opening_snap_half_width(),
            upper_snap_half_width=_thin_snap_top_connector_opening_snap_half_width(),
            top_half_width=_thin_snap_top_connector_opening_top_half_width(),
            lower_z=_thin_snap_top_connector_opening_lower_z(),
            top_z=_thin_snap_top_connector_opening_top_z(),
            bottom_z=min(_thin_snap_top_connector_bottom_z(), _thin_snap_top_connector_opening_lower_z()) - TOLLERANCE
        )
    );

// Build the left half of the snap opening. The snap lobes are defined as short
// 45-degree transitions between the narrow opening and wider snap relief.
function _thin_snap_top_opening_left_points(
    bottom_half_width,
    lower_snap_half_width,
    upper_snap_half_width,
    top_half_width,
    lower_z,
    top_z,
    bottom_z
) =
    let(
        lower_snap_depth = lower_snap_half_width - bottom_half_width,
        upper_snap_depth = upper_snap_half_width - top_half_width,
        lower_snap_z = lower_z + lower_snap_depth,
        upper_snap_z = top_z - upper_snap_depth
    )
    [
        [_thin_snap_top_sketch_mirror_x() - bottom_half_width, bottom_z],
        [_thin_snap_top_sketch_mirror_x() - bottom_half_width, lower_z],
        [_thin_snap_top_sketch_mirror_x() - lower_snap_half_width, lower_snap_z],
        [_thin_snap_top_sketch_mirror_x() - upper_snap_half_width, upper_snap_z],
        [_thin_snap_top_sketch_mirror_x() - top_half_width, top_z]
    ];

// Mirror a left-side profile around the sketch centerline, preserving point
// order so the final polygon stays valid for OpenSCAD.
function _thin_snap_top_mirrored_opening_points(left_points) =
    concat(
        left_points,
        [
            for (i = [len(left_points)-1:-1:0])
            [_thin_snap_top_sketch_width() - left_points[i].x, left_points[i].y]
        ]
    );

// Convert from sketch coordinates, whose origin is the lower-left corner of the
// cutout envelope, into centered OpenSCAD profile coordinates.
function _thin_snap_top_centered_points(points) = [
    for (point = points)
    [point.x - _thin_snap_top_sketch_mirror_x(), point.y]
];

// Local sketch envelope before centering. The cutout constants stay fixed;
// friction, z-axis fit, and snap flex only shrink or reshape the connector.
function _thin_snap_top_sketch_width() = 5.30;
function _thin_snap_top_sketch_mirror_x() = _thin_snap_top_sketch_width() / 2;
function _thin_snap_top_sketch_top_z() = 4.15;
function _thin_snap_top_cutout_bottom_z() = 0.60;
function _thin_snap_top_cutout_opening_lower_z() = _thin_snap_top_cutout_bottom_z() + 0.80;
function _thin_snap_top_cutout_opening_top_z() = _thin_snap_top_cutout_opening_lower_z() + 0.50 + thin_snap_top_snap_flex * 2;
function _thin_snap_top_cutout_opening_half_width() = 0.90;
function _thin_snap_top_cutout_opening_snap_half_width() = _thin_snap_top_cutout_opening_half_width() + thin_snap_top_snap_flex;

// Connector bottom follows z-axis fit for insertion clearance at the feet.
function _thin_snap_top_connector_bottom_z() =
    _thin_snap_top_cutout_bottom_z() + thin_snap_top_z_axis_fit;
// Cutouts extend TOLLERANCE above the nominal baseplate top; cancel that offset
// so the connector deck follows the actual top_cutoff plane.
function _thin_snap_top_connector_top_z() =
    _thin_snap_top_sketch_top_z() - top_cutoff - TOLLERANCE;
function _thin_snap_top_connector_outer_side_x() =
    thin_snap_top_snap_flex + thin_snap_top_friction_fit;
// Width of one connector foot between the outer wall and the inner opening.
// Used to cap the small 2D foot chamfer.
function _thin_snap_top_connector_foot_width() =
    _thin_snap_top_sketch_mirror_x()
    - _thin_snap_top_connector_opening_half_width()
    - _thin_snap_top_connector_outer_side_x();

// Connector opening
// Use the larger of friction and z-axis fit for diagonal snap relief. This keeps
// the snap transitions printable while still leaving enough insertion clearance.
function _thin_snap_diagonal_fit() =
    max(thin_snap_top_friction_fit, thin_snap_top_z_axis_fit);

// Lower connector opening starts slightly below the cutout snap transition so
// the printed snap has material to flex into the cutout.
function _thin_snap_top_connector_opening_lower_z() =
    _thin_snap_top_cutout_opening_lower_z() - _thin_snap_diagonal_fit() + thin_snap_top_friction_fit;
function _thin_snap_top_connector_opening_half_width() =
    _thin_snap_top_cutout_opening_half_width() + thin_snap_top_friction_fit;

// Upper connector opening moves with z-axis fit, but the outer deck above it now
// follows top_cutoff so the top face matches the cropped baseplate height.
function _thin_snap_top_connector_opening_top_z() =
    _thin_snap_top_cutout_opening_top_z() + thin_snap_top_z_axis_fit;
function _thin_snap_top_connector_opening_top_half_width() =
    _thin_snap_top_cutout_opening_half_width() + _thin_snap_diagonal_fit() - thin_snap_top_z_axis_fit;

// Snap relief is wider than the straight opening by snap_flex on each side.
function _thin_snap_top_connector_opening_snap_half_width() =
    _thin_snap_top_connector_opening_half_width() + thin_snap_top_snap_flex;
function _thin_snap_top_connector_opening_snap_x() =
    _thin_snap_top_sketch_mirror_x() - _thin_snap_top_connector_opening_snap_half_width();

// Standalone spacing and body extrusion depths use the final fitted connector
// dimensions, not the cutout envelope.
function _thin_snap_top_connector_width() =
    _thin_snap_top_sketch_width() - 2*_thin_snap_top_connector_outer_side_x();
function _thin_snap_top_cutout_width() = _thin_snap_top_sketch_width();
function _thin_snap_top_body_depth(cutout=false) =
    cutout ? _thin_snap_top_cutout_depth() : _thin_snap_top_connector_depth();
function _thin_snap_top_connector_depth() = 4.20 - 2*thin_snap_top_friction_fit;
function _thin_snap_top_cutout_depth() = 4.20 + 2*TOLLERANCE;
