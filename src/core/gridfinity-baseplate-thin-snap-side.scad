// Thin snap-together side connector geometry.

/* [Thin Snap Together Side Settings] */
thin_snap_side_line_width = 0.40; // [0.30:0.05:0.60]
thin_snap_side_friction_fit = 0.10; // [0:0.05:0.30]
thin_snap_side_snap_flex = 0.30; // [0.10:0.05:0.60]
thin_snap_side_rounding = 0.45; // [0.30:0.05:0.60]
thin_snap_side_z_axis_fit = 0.20; // [0:0.05:0.40]

module cutter_snap_together_side(gx, gy, size = l_grid) {
    assert(gx >= 1);
    assert(gy >= 1);

    if (gx > 1) {
        for (x = [1:gx-1]) {
            translate([(-gx/2 + x) * size, -gy * size/2, 0])
            cutter_snap_connector_side_edge();

            translate([(-gx/2 + x) * size, gy * size/2, 0])
            rotate([0, 0, 180])
            cutter_snap_connector_side_edge();
        }
    }

    if (gy > 1) {
        for (y = [1:gy-1]) {
            translate([-gx * size/2, (-gy/2 + y) * size, 0])
            rotate([0, 0, -90])
            cutter_snap_connector_side_edge();

            translate([gx * size/2, (-gy/2 + y) * size, 0])
            rotate([0, 0, 90])
            cutter_snap_connector_side_edge();
        }
    }
}

module cutter_snap_connector_side_edge() {
    socket_floor_z = _thin_snap_side_socket_floor_z();
    socket_center_z = socket_floor_z + _thin_snap_side_cutout_height() / 2;

    // The full connector cutout straddles the outside edge. Only the inboard half intersects
    // the baseplate, leaving one snap nub inside each side socket.
    translate([0, 0, socket_center_z])
    translate([0, 0, -_thin_snap_side_cutout_height() / 2])
    _thin_snap_side_connector(cutout=true);
}

module _thin_snap_side_connector(cutout=false) {
    assert(is_bool(cutout));

    difference() {
        _thin_snap_side_lofted_profile(
            line_width=thin_snap_side_line_width,
            snap_flex=thin_snap_side_snap_flex,
            friction_fit=thin_snap_side_friction_fit,
            height=_thin_snap_side_body_height(cutout),
            cutout=cutout
        );

        _thin_snap_side_side_cap_reliefs(
            cutout=cutout,
            chamfer=_thin_snap_side_side_cap_chamfer(cutout)
        );
    }
}

module _thin_snap_side_connector_display(cutout=false) {
    assert(is_bool(cutout));

    if ($preview && cutout) {
        // Pre-render the small standalone overlay so Preview does not show the
        // negative chamfer helpers through the transparent cutout body.
        render(convexity=8)
        _thin_snap_side_connector(cutout=cutout);
    } else {
        _thin_snap_side_connector(cutout=cutout);
    }
}

module _thin_snap_side_lofted_profile(line_width, snap_flex, friction_fit, height, cutout=false) {
    assert(line_width > 0);
    assert(snap_flex >= 0);
    assert(friction_fit >= 0);
    assert(height > 0);
    assert(is_bool(cutout));

    scale_x = _thin_snap_side_loft_end_scale(cutout);
    z_points = _thin_snap_side_loft_z_points(height);

    for (i = [0:len(z_points)-2]) {
        z0 = z_points[i];
        z1 = z_points[i+1];
        scale0 = _thin_snap_side_loft_scale_at_z(z0, height, scale_x);
        scale1 = _thin_snap_side_loft_scale_at_z(z1, height, scale_x);

        translate([0, 0, z0])
        linear_extrude(z1 - z0, scale=[scale1/scale0, 1], convexity=8)
        scale([scale0, 1])
        _thin_snap_side_profile_2d(line_width, snap_flex, friction_fit, cutout);
    }
}

module _thin_snap_side_profile_2d(line_width, snap_flex, friction_fit, cutout=false) {
    assert(line_width > 0);
    assert(snap_flex >= 0);
    assert(friction_fit >= 0);
    assert(is_bool(cutout));

    if (cutout) {
        _thin_snap_side_cutout_profile_2d(line_width, snap_flex, friction_fit);
    } else {
        _thin_snap_side_connector_profile_2d(line_width, snap_flex, friction_fit);
    }
}

module _thin_snap_side_side_cap_reliefs(cutout=false, chamfer=0) {
    assert(is_bool(cutout));
    assert(chamfer >= 0);

    if (chamfer > 0) {
        half_width = _thin_snap_side_sketch_half_width(cutout);
        half_length = _thin_snap_side_sketch_half_length(cutout);
        body_height = _thin_snap_side_body_height(cutout);
        end_scale = _thin_snap_side_loft_end_scale(cutout);
        epsilon = TOLLERANCE;
        effective_chamfer = min(chamfer, min(half_width - epsilon, body_height/2 - epsilon));
        cutter_length = 2*(half_length + effective_chamfer + epsilon);

        // Reduce only the upper/lower side cap edges along the insertion axis.
        for (z_side = [-1, 1]) {
            cap_z = z_side > 0 ? body_height : 0;
            outer_z = cap_z + z_side*epsilon;
            inner_z = cap_z - z_side*effective_chamfer;
            inner_half_width = half_width
                * _thin_snap_side_loft_scale_at_z(inner_z, body_height, end_scale);
            outside_half_width = inner_half_width + epsilon;
            cap_inner_half_width = inner_half_width - effective_chamfer;

            for (x_side = [-1, 1]) {
                outer_x = x_side*outside_half_width;
                inner_x = x_side*cap_inner_half_width;

                hull() {
                    translate([outer_x, 0, outer_z])
                    cube([epsilon, cutter_length, epsilon], center=true);

                    translate([inner_x, 0, outer_z])
                    cube([epsilon, cutter_length, epsilon], center=true);

                    translate([outer_x, 0, inner_z])
                    cube([epsilon, cutter_length, epsilon], center=true);
                }
            }
        }
    }
}

module _thin_snap_side_connector_profile_2d(line_width, snap_flex, friction_fit) {
    assert(line_width > 0);
    assert(snap_flex >= 0);
    assert(friction_fit >= 0);

    half_width = _thin_snap_side_sketch_half_width(false, line_width, friction_fit);
    half_length = _thin_snap_side_sketch_half_length(false, friction_fit);
    jaw_radius = _thin_snap_side_sketch_jaw_radius(false, friction_fit);
    outer_radius = _thin_snap_side_outer_radius(line_width, false, friction_fit);
    mouth_half_width = _thin_snap_side_mouth_half_width(snap_flex, false, friction_fit);
    cap_radius = line_width;
    cap_center_x = mouth_half_width + cap_radius;
    cap_center_y = half_length - cap_radius;
    snap_center_y = _thin_snap_side_sketch_snap_center_y(line_width, snap_flex, false, friction_fit);
    top_straight_y = 1.00;
    neck_half_width = 1.40;

    assert(cap_center_x < jaw_radius + cap_radius);
    assert(neck_half_width < outer_radius);
    assert(abs(half_length - snap_center_y) < outer_radius);

    // The lower arm transition is the Fusion tangency chain: a lineWidth-radius cap
    // circle touches the snap-flex vertical, bottom edge, inner jaw circle and outer circle.
    outer_top_y = snap_center_y - outer_radius;
    outer_neck_y = snap_center_y - sqrt(pow(outer_radius, 2) - pow(neck_half_width, 2));
    cap_angle = atan2(cap_center_y - snap_center_y, cap_center_x);
    outer_neck_angle = atan2(outer_neck_y - snap_center_y, neck_half_width);
    inner_left_angle = 180 - cap_angle - 360;

    one_end_profile = concat(
        [
            [half_width, 0],
            [half_width, top_straight_y],
            [neck_half_width, outer_top_y],
            [neck_half_width, outer_neck_y]
        ],
        arc_points(
            [0, snap_center_y],
            outer_radius,
            outer_neck_angle,
            cap_angle,
            32
        ),
        arc_points(
            [cap_center_x, cap_center_y],
            cap_radius,
            cap_angle,
            cap_angle + 180,
            24
        ),
        arc_points(
            [0, snap_center_y],
            jaw_radius,
            cap_angle,
            inner_left_angle,
            64
        ),
        arc_points(
            [-cap_center_x, cap_center_y],
            cap_radius,
            -cap_angle,
            180 - cap_angle,
            24
        ),
        arc_points(
            [0, snap_center_y],
            outer_radius,
            180 - cap_angle,
            180 - outer_neck_angle,
            32
        ),
        [
            [-neck_half_width, outer_neck_y],
            [-neck_half_width, outer_top_y],
            [-half_width, top_straight_y],
            [-half_width, 0]
        ]
    );

    for (y_side = [-1, 1]) {
        polygon([for (point = one_end_profile) [point.x, y_side*point.y]]);
    }
}

module _thin_snap_side_cutout_profile_2d(line_width, snap_flex, friction_fit) {
    assert(line_width > 0);
    assert(snap_flex >= 0);
    assert(friction_fit >= 0);

    half_width = _thin_snap_side_sketch_half_width(true, line_width, friction_fit);
    half_length = _thin_snap_side_sketch_half_length(true, friction_fit);

    difference() {
        union() {
            for (y_side = [-1, 1]) {
                polygon([
                    [-half_width, 0],
                    [half_width, 0],
                    [half_width, y_side*half_length],
                    [-half_width, y_side*half_length]
                ]);
            }
        }

        _thin_snap_side_cutout_nub_profile_2d(line_width, snap_flex, friction_fit);
    }
}

module _thin_snap_side_cutout_nub_profile_2d(line_width, snap_flex, friction_fit) {
    assert(line_width > 0);
    assert(snap_flex >= 0);
    assert(friction_fit >= 0);

    half_length = _thin_snap_side_sketch_half_length(true, friction_fit);
    jaw_radius = _thin_snap_side_sketch_jaw_radius(true, friction_fit);
    cap_radius = line_width;
    mouth_half_width = _thin_snap_side_mouth_half_width(snap_flex, true, friction_fit);
    cap_center_x = mouth_half_width + cap_radius;
    cap_center_y = half_length - cap_radius;
    snap_center_y = _thin_snap_side_sketch_snap_center_y(line_width, snap_flex, true, friction_fit);
    cap_angle = atan2(cap_center_y - snap_center_y, cap_center_x);
    inner_left_angle = 180 - cap_angle - 360;

    assert(cap_center_x < jaw_radius + cap_radius);

    one_end_nub = concat(
        [
            [cap_center_x, half_length]
        ],
        arc_points(
            [cap_center_x, cap_center_y],
            cap_radius,
            90,
            cap_angle + 180,
            18
        ),
        arc_points(
            [0, snap_center_y],
            jaw_radius,
            cap_angle,
            inner_left_angle,
            64
        ),
        arc_points(
            [-cap_center_x, cap_center_y],
            cap_radius,
            -cap_angle,
            90,
            18
        ),
        [
            [-cap_center_x, half_length]
        ]
    );

    for (y_side = [-1, 1]) {
        polygon([for (point = one_end_nub) [point.x, y_side*point.y]]);
    }
}

function _thin_snap_side_connector_height() =
    _thin_snap_side_connector_target_height();
function _thin_snap_side_body_height(cutout=false) =
    cutout ? _thin_snap_side_cutout_height() : _thin_snap_side_connector_height();
function _thin_snap_side_cutout_overlay_z_offset() =
    (_thin_snap_side_connector_height() - _thin_snap_side_cutout_height()) / 2;
function _thin_snap_side_standalone_spacing() =
    _thin_snap_side_sketch_half_width(false) + _thin_snap_side_sketch_half_width(true) + 3.00;
function _thin_snap_side_connector_standalone_translation() =
    render_connector && render_cutout ? [-_thin_snap_side_standalone_spacing(), 0, 0] : [0, 0, 0];
function _thin_snap_side_cutout_standalone_translation() =
    render_connector && render_cutout
        ? [_thin_snap_side_standalone_spacing(), 0, _thin_snap_side_cutout_overlay_z_offset()]
        : [0, 0, _thin_snap_side_cutout_overlay_z_offset()];
function _thin_snap_side_mirror_blend_height() = 1;
function _thin_snap_side_mirror_blend_steps() = 4;
function _thin_snap_side_loft_z_points(height) =
    let(
        half_height = height / 2,
        blend_height = min(_thin_snap_side_mirror_blend_height(), half_height),
        steps = _thin_snap_side_mirror_blend_steps()
    )
    concat(
        [0],
        blend_height < half_height ? [half_height - blend_height] : [],
        [for (i = [1:steps]) half_height - blend_height + blend_height * i / steps],
        [for (i = [1:steps]) half_height + blend_height * i / steps],
        blend_height < half_height ? [height] : []
    );
function _thin_snap_side_loft_scale_at_z(z, height, end_scale) =
    let(
        half_height = height / 2,
        blend_height = min(_thin_snap_side_mirror_blend_height(), half_height),
        blend_fraction = blend_height / half_height,
        center_distance_fraction = abs(z - half_height) / half_height,
        eased_distance = center_distance_fraction <= blend_fraction
            ? _thin_snap_side_center_blend_distance(center_distance_fraction, blend_fraction)
            : center_distance_fraction
    )
    1 - (1 - end_scale) * eased_distance;
function _thin_snap_side_center_blend_distance(distance_fraction, blend_fraction) =
    2 * pow(distance_fraction, 2) / blend_fraction
    - pow(distance_fraction, 3) / pow(blend_fraction, 2);
function _thin_snap_side_loft_end_scale(cutout=false) =
    1 - (thin_snap_side_rounding / 2) / _thin_snap_side_sketch_half_width(cutout);

// The bottom-padding wrapper trims the built-in Gridfinity foot clearance when
// bottom_padding=0, so this lands the socket floor 0.40 mm above the final bottom.
function _thin_snap_side_socket_floor_z() =
    BASEPLATE_HEIGHT - _BASEPLATE_PROFILE[3].y + 0.40;
function _thin_snap_side_side_cap_chamfer(cutout=false) =
    cutout ? _thin_snap_side_cutout_chamfer() : _thin_snap_side_connector_cap_chamfer();
function _thin_snap_side_connector_cap_chamfer() =
    _thin_snap_side_cutout_chamfer();
function _thin_snap_side_cutout_chamfer() = 0.40;

// The connector is the printed part. The cutout grows around it by the fit
// values, preserving the original 2.20/2.60 mm default pair.
function _thin_snap_side_connector_target_height() = 2.20;
function _thin_snap_side_cutout_height() =
    _thin_snap_side_connector_target_height() + 2*thin_snap_side_z_axis_fit;
function _thin_snap_side_sketch_half_width(
    cutout=false,
    line_width=thin_snap_side_line_width,
    friction_fit=thin_snap_side_friction_fit
) =
    _thin_snap_side_outer_radius(line_width, false, friction_fit)
    + _thin_snap_side_flat_side_margin()
    + (cutout ? friction_fit : 0);
function _thin_snap_side_sketch_half_length(
    cutout=false,
    friction_fit=thin_snap_side_friction_fit
) =
    _thin_snap_side_connector_half_length() + (cutout ? friction_fit : 0);
function _thin_snap_side_sketch_jaw_radius(
    cutout=false,
    friction_fit=thin_snap_side_friction_fit
) =
    cutout
        ? max(_thin_snap_side_connector_jaw_radius() - friction_fit, 0.01)
        : _thin_snap_side_connector_jaw_radius();
function _thin_snap_side_connector_half_length() = 4.90;
function _thin_snap_side_connector_jaw_radius() = 0.70;
function _thin_snap_side_flat_side_margin() = 0.20;
function _thin_snap_side_outer_radius(
    line_width=thin_snap_side_line_width,
    cutout=false,
    friction_fit=thin_snap_side_friction_fit
) =
    _thin_snap_side_sketch_jaw_radius(cutout, friction_fit) + 2*line_width + (cutout ? friction_fit : 0);
function _thin_snap_side_mouth_half_width(
    snap_flex=thin_snap_side_snap_flex,
    cutout=false,
    friction_fit=thin_snap_side_friction_fit
) =
    max(_thin_snap_side_sketch_jaw_radius(cutout, friction_fit) - snap_flex, 0.01);
function _thin_snap_side_sketch_snap_center_y(
    line_width=thin_snap_side_line_width,
    snap_flex=thin_snap_side_snap_flex,
    cutout=false,
    friction_fit=thin_snap_side_friction_fit
) =
    let(
        jaw_radius = _thin_snap_side_sketch_jaw_radius(cutout, friction_fit),
        cap_radius = line_width,
        mouth_half_width = _thin_snap_side_mouth_half_width(snap_flex, cutout, friction_fit),
        cap_center_x = mouth_half_width + cap_radius,
        cap_center_y = _thin_snap_side_sketch_half_length(cutout, friction_fit) - cap_radius,
        center_distance = jaw_radius + cap_radius
    )
    // Position the concentric circles so the cap circle remains tangent to the jaw circle.
    cap_center_y - sqrt(pow(center_distance, 2) - pow(cap_center_x, 2));
