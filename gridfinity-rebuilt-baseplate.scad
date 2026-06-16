// ===== INFORMATION ===== //
/*
 IMPORTANT: rendering will be better in development builds and not the official release of OpenSCAD, but it makes rendering only take a couple seconds, even for comically large bins.

https://github.com/kennetek/gridfinity-rebuilt-openscad

*/

include <src/core/standard.scad>
include <src/core/gridfinity-baseplate.scad>
use <src/core/gridfinity-rebuilt-utility.scad>
use <src/core/gridfinity-rebuilt-holes.scad>
use <src/helpers/generic-helpers.scad>
use <src/helpers/grid.scad>

// ===== PARAMETERS ===== //

/* [Setup Parameters] */
$fa = 2;
$fs = 0.10;

/* [General Settings] */
// number of bases along x-axis
gridx = 1;
// number of bases along y-axis
gridy = 1;
// height removed from the top of the baseplate
top_cutoff = 0.50; // [0:0.05:5]
// extra material added below the baseplate
bottom_padding = 0.35; // [0:0.05:20]
// margin removed from each outside edge
outer_margin = 0.10; // [0:0.01:0.50]
// outside corner radius
corner_radius = 4; // [0:0.05:4]

/* [Screw Together Settings - Defaults work for M3 and 4-40] */
// screw diameter
d_screw = 3.35;
// screw head diameter
d_screw_head = 5;
// screw spacing distance
screw_spacing = .5;
// number of screws per grid block
n_screws = 1; // [1:3]


/* [Fit to Drawer] */
// minimum length of baseplate along x (leave zero to ignore, will automatically fill area if gridx is zero)
distancex = 0;
// minimum length of baseplate along y (leave zero to ignore, will automatically fill area if gridy is zero)
distancey = 0;

// where to align extra space along x
fitx = 0; // [-1:0.1:1]
// where to align extra space along y
fity = 0; // [-1:0.1:1]


/* [Styles] */

// baseplate styles
style_plate = 3; // [0: thin, 1:weighted, 2:skeletonized, 3: screw together, 4: screw together minimal, 5: thin snap together]


// hole styles
style_hole = 0; // [0:none, 1:countersink, 2:counterbore]

/* [Magnet Hole] */
// Baseplate will have holes for 6mm Diameter x 2mm high magnets.
enable_magnet = true;
// Magnet holes will have crush ribs to hold the magnet.
crush_ribs = true;
// Magnet holes will have a chamfer to ease insertion.
chamfer_holes = true;

hole_options = bundle_hole_options(refined_hole=false, magnet_hole=enable_magnet, screw_hole=false, crush_ribs=crush_ribs, chamfer=chamfer_holes, supportless=false);

// ===== IMPLEMENTATION ===== //

color("tomato")
gridfinityBaseplate([gridx, gridy], l_grid, [distancex, distancey], style_plate, hole_options, style_hole, [fitx, fity]);

// ===== CONSTRUCTION ===== //

/**
 * @brief Create a baseplate.
 * @param grid_size_bases Number of Gridfinity bases.
 *        2d Vector. [x, y].
 *        Set to [0, 0] to auto calculate using min_size_mm.
 * @param length X,Y size of a single Gridfinity base.
 * @param min_size_mm Minimum size of the baseplate. [x, y]
 *                    Extra space is filled with solid material.
 *                    Enables "Fit to Drawer."
 * @param sp Baseplate Style
 * @param hole_options
 * @param sh Style of screw hole allowing the baseplate to be mounted to something.
 * @param fit_offset Determines where padding is added.
 */
module gridfinityBaseplate(grid_size_bases, length, min_size_mm, sp, hole_options, sh, fit_offset = [0, 0]) {

    assert(is_list(grid_size_bases) && len(grid_size_bases) == 2,
        "grid_size_bases must be a 2d list");
    assert(is_list(min_size_mm) && len(min_size_mm) == 2,
        "min_size_mm must be a 2d list");
    assert(is_list(fit_offset) && len(fit_offset) == 2,
        "fit_offset must be a 2d list");
    assert(grid_size_bases.x > 0 || min_size_mm.x > 0,
        "Must have positive x grid amount!");
    assert(grid_size_bases.y > 0 || min_size_mm.y > 0,
        "Must have positive y grid amount!");
    assert(top_cutoff >= 0,
        "top_cutoff may not be negative.");
    assert(bottom_padding >= 0,
        "bottom_padding may not be negative.");
    assert(outer_margin >= 0,
        "outer_margin may not be negative.");
    assert(corner_radius >= 0,
        "corner_radius may not be negative.");

    additional_height = calculate_offset(sp, hole_options[1], sh);

    // Final height of the baseplate. In mm.
    baseplate_height_mm = additional_height + BASEPLATE_HEIGHT;
    assert(top_cutoff < baseplate_height_mm,
        "top_cutoff must be smaller than the baseplate height.");
    render_height_limit = baseplate_height_mm - top_cutoff;
    // The Gridfinity baseplate profile includes 0.35 mm of bottom clearance.
    built_in_bottom_padding = BASEPLATE_HEIGHT - _BASEPLATE_PROFILE[3].y;
    bottom_padding_delta = bottom_padding - built_in_bottom_padding;
    final_height_mm = render_height_limit + bottom_padding_delta;
    assert(final_height_mm > 0,
        "bottom_padding is too small for the selected top_cutoff.");

    // Final size in number of bases
    grid_size = [for (i = [0:1])
        grid_size_bases[i] == 0 ? floor(min_size_mm[i]/length) : grid_size_bases[i]];

    // Final size of the base before padding. In mm.
    grid_size_mm = concat(grid_size * length, [baseplate_height_mm]);

    // Final nominal size, before shrinking the outside edges for print clearance.
    nominal_size_mm = [
        max(grid_size_mm.x, min_size_mm.x),
        max(grid_size_mm.y, min_size_mm.y),
        render_height_limit
    ];
    assert(2*outer_margin < nominal_size_mm.x && 2*outer_margin < nominal_size_mm.y,
        "outer_margin is too large for the baseplate size.");

    // Final size, including padding and outside edge margin. In mm.
    size_mm = [
        nominal_size_mm.x - 2*outer_margin,
        nominal_size_mm.y - 2*outer_margin,
        nominal_size_mm.z
    ];

    // Amount of padding needed to fit to a specific drawer size. In mm.
    padding_mm = [
        nominal_size_mm.x - grid_size_mm.x,
        nominal_size_mm.y - grid_size_mm.y,
        0
    ];

    is_padding_needed = padding_mm != [0, 0, 0];

    //Convert the fit offset to percent of how much will be added to the positive axes.
    // -1 : 1 -> 0 : 1
    fit_percent_positive = [for (i = [0:1]) (fit_offset[i] + 1) / 2];

    padding_start_point = [
        -grid_size_mm.x/2 - padding_mm.x * (1 - fit_percent_positive.x),
        -grid_size_mm.y/2 - padding_mm.y * (1 - fit_percent_positive.y),
        0
    ] + [outer_margin, outer_margin, 0];

    corner_points = [
        padding_start_point + [size_mm.x, size_mm.y, 0],
        padding_start_point + [0, size_mm.y, 0],
        padding_start_point,
        padding_start_point + [size_mm.x, 0, 0],
    ];

    echo(str("Number of Grids per axes (X, Y)]: ", grid_size));
    echo(str("Final size (in mm): ", [size_mm.x, size_mm.y, final_height_mm]));
    if (is_padding_needed) {
        echo(str("Padding +X (in mm): ", padding_mm.x * fit_percent_positive.x));
        echo(str("Padding -X (in mm): ", padding_mm.x * (1 - fit_percent_positive.x)));
        echo(str("Padding +Y (in mm): ", padding_mm.y * fit_percent_positive.y));
        echo(str("Padding -Y (in mm): ", padding_mm.y * (1 - fit_percent_positive.y)));
    }

    screw_together = sp == 3 || sp == 4;
    snap_together = sp == 5;
    minimal = sp == 0 || sp == 4 || snap_together;

    _apply_bottom_padding(bottom_padding_delta, padding_start_point, size_mm) {
        difference() {
            union() {
                // Baseplate itself
                difference() {
                    translate(padding_start_point)
                    cube([size_mm.x, size_mm.y, baseplate_height_mm]);
                    // Replicated Single Baseplate piece
                    pattern_grid(grid_size, [length, length], true, true) {
                        if (minimal) {
                            translate([0, 0, -TOLLERANCE/2])
                            baseplate_cutter([length, length], baseplate_height_mm+TOLLERANCE);
                        } else {
                            translate([0, 0, additional_height+TOLLERANCE/2])
                            baseplate_cutter([length, length]);

                            // Bottom/through pattern for the solid baseplates.
                            if (sp == 1) {
                                cutter_weight();
                            } else if (sp == 2 || sp == 3) {
                                translate([0,0,-TOLLERANCE])
                                linear_extrude(additional_height + (2 * TOLLERANCE))
                                profile_skeleton();
                            }

                            // Add holes to the solid baseplates.
                            hole_pattern(){
                                // Magnet hole
                                translate([0, 0, additional_height+TOLLERANCE])
                                mirror([0, 0, 1])
                                block_base_hole(hole_options);

                                translate([0,0,-TOLLERANCE])
                                if (sh == 1) {
                                    cutter_countersink();
                                } else if (sh == 2) {
                                    cutter_counterbore();
                                }
                            }
                        }
                    }
                }
            }

            // Round the outside corners (Including Padding)
            for(i = [0:len(corner_points) - 1]) {
                point = corner_points[i];
                translate([
                    point.x + (corner_radius * -sign(point.x)),
                    point.y + (corner_radius * -sign(point.y)),
                    0
                ])
                rotate([0, 0, i*90])
                square_baseplate_corner(additional_height, true, corner_radius);
            }

            if (screw_together) {
                translate([0, 0, additional_height/2])
                cutter_screw_together(grid_size.x, grid_size.y, length);
            }

            if (snap_together) {
                cutter_snap_together(grid_size.x, grid_size.y, length);
            }

            if (render_height_limit < baseplate_height_mm) {
                translate([padding_start_point.x - TOLLERANCE, padding_start_point.y - TOLLERANCE, render_height_limit])
                cube([
                    size_mm.x + 2*TOLLERANCE,
                    size_mm.y + 2*TOLLERANCE,
                    baseplate_height_mm - render_height_limit + TOLLERANCE
                ]);
            }
        }
    }
}

function calculate_offset(style_plate, enable_magnet, style_hole) =
    assert(style_plate >=0 && style_plate <=5)
    let (screw_together = style_plate == 3 || style_plate == 4)
    screw_together ? 6.75 :
    (style_plate==0 || style_plate==5) ? 0 :
    style_plate==1 ? bp_h_bot :
    calculate_offset_skeletonized(enable_magnet, style_hole);

function calculate_offset_skeletonized(enable_magnet, style_hole) =
    h_skel + (enable_magnet ? MAGNET_HOLE_DEPTH : 0) +
    (
        style_hole==0 ? d_screw :
        style_hole==1 ? BASEPLATE_SCREW_COUNTERSINK_ADDITIONAL_RADIUS : // Only works because countersink is at 45 degree angle!
        BASEPLATE_SCREW_COUNTERBORE_HEIGHT
    );

module cutter_weight() {
    union() {
        linear_extrude(bp_cut_depth*2,center=true)
        square(bp_cut_size, center=true);
        pattern_circular(4)
        translate([0,10,0])
        linear_extrude(bp_rcut_depth*2,center=true)
        union() {
            square([bp_rcut_width, bp_rcut_length], center=true);
            translate([0,bp_rcut_length/2,0])
            circle(d=bp_rcut_width);
        }
    }
}
module hole_pattern(){
    pattern_circular(4)
    translate([l_grid/2-d_hole_from_side, l_grid/2-d_hole_from_side, 0]) {
        render();
        children();
    }
}

module cutter_countersink(){
    screw_hole(SCREW_HOLE_RADIUS + TOLLERANCE, 2*BASE_PROFILE_HEIGHT,
        false, BASEPLATE_SCREW_COUNTERSINK_ADDITIONAL_RADIUS);
}

module cutter_counterbore(){
    screw_radius = SCREW_HOLE_RADIUS + TOLLERANCE;
    counterbore_height = BASEPLATE_SCREW_COUNTERBORE_HEIGHT + 2*LAYER_HEIGHT;
    union(){
        cylinder(h=2*BASE_PROFILE_HEIGHT, r=screw_radius);
        difference() {
            cylinder(h = counterbore_height, r=BASEPLATE_SCREW_COUNTERBORE_RADIUS);
            make_hole_printable(screw_radius, BASEPLATE_SCREW_COUNTERBORE_RADIUS, counterbore_height);
        }
    }
}

/**
 * @brief Added or removed from the baseplate to square off or round the corners.
 * @param height Baseplate's height, excluding lip and clearance height.
 * @param subtract If the corner should be scaled to allow subtraction.
 */
module square_baseplate_corner(height=0, subtract=false, radius=BASEPLATE_OUTER_RADIUS) {
    assert(height >= 0);
    assert(is_bool(subtract));
    assert(radius >= 0);

    subtract_ammount = subtract ? TOLLERANCE : 0;

    if (radius > 0) {
        translate([0, 0, -subtract_ammount])
        linear_extrude(height + BASEPLATE_HEIGHT + (2 * subtract_ammount))
        difference() {
            square(radius + subtract_ammount , center=false);
            circle(r=radius);
        }
    }
}

/**
 * @brief 2d Cutter to skeletonize the baseplate.
 * @param size Width/Length of a single baseplate.  Only set if deviating from the standard!
 * @example difference(){
 *              cube(large_number);
 *              linear_extrude(large_number+TOLLERANCE)
 *              profile_skeleton();
 *          }
 */
module profile_skeleton(size=l_grid) {
    l = baseplate_inner_size([size, size]).x;

    offset(r_skel)
    difference() {
        square(l-2*r_skel, center = true);

        hole_pattern()
        offset(MAGNET_HOLE_RADIUS+r_skel+2)
        square([l,l]);
    }
}

module cutter_screw_together(gx, gy, size = l_grid) {

    screw(gx, gy);
    rotate([0,0,90])
    screw(gy, gx);

    module screw(a, b) {
        copy_mirror([1,0,0])
        translate([a*size/2, 0, 0])
        pattern_grid([1, b], [1, size], true, true)
        pattern_grid([1, n_screws], [1, d_screw_head + screw_spacing], true, true)
        rotate([0,90,0])
        cylinder(h=size/2, d=d_screw, center = true);
    }
}

module _apply_bottom_padding(bottom_padding_delta, start_point, size) {
    assert(is_num(bottom_padding_delta));
    assert(is_list(start_point) && len(start_point) == 3);
    assert(is_list(size) && len(size) == 3);

    if (bottom_padding_delta < 0) {
        trim_height = -bottom_padding_delta;

        translate([0, 0, -trim_height])
        difference() {
            children();

            translate([start_point.x - TOLLERANCE, start_point.y - TOLLERANCE, -TOLLERANCE])
            cube([
                size.x + 2*TOLLERANCE,
                size.y + 2*TOLLERANCE,
                trim_height + TOLLERANCE
            ]);
        }
    } else if (bottom_padding_delta > 0) {
        translate([0, 0, bottom_padding_delta])
        union() {
            children();

            // Reuse the first printable layer as the extrusion footprint for added bottom padding.
            translate([0, 0, -bottom_padding_delta])
            linear_extrude(bottom_padding_delta + TOLLERANCE)
            projection(cut=true)
            translate([0, 0, -LAYER_HEIGHT])
            children();
        }
    } else {
        children();
    }
}

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

function arc_points(center, radius, start_angle, end_angle, steps) = [
    for (i = [0:steps])
    let(angle = start_angle + (end_angle - start_angle) * i / steps)
    center + radius * [cos(angle), sin(angle)]
];

function fillet_arc_points(prev, corner, next, radius, steps) =
    let(
        incoming = unit_vector(prev - corner),
        outgoing = unit_vector(next - corner),
        angle = acos(clamp(dot_product(incoming, outgoing), -1, 1)),
        tangent_distance = radius / tan(angle/2),
        start_point = corner + incoming * tangent_distance,
        end_point = corner + outgoing * tangent_distance,
        center = corner + unit_vector(incoming + outgoing) * radius / sin(angle/2),
        start_angle = atan2(start_point.y - center.y, start_point.x - center.x),
        end_angle = atan2(end_point.y - center.y, end_point.x - center.x),
        // Fillets use the short arc between tangent points; the long arc cuts through the profile.
        end_angle_short = start_angle + short_angle_delta(end_angle - start_angle)
    )
    arc_points(center, radius, start_angle, end_angle_short, steps);

function unit_vector(v) = v / sqrt(dot_product(v, v));
function dot_product(a, b) = a.x*b.x + a.y*b.y;
function clamp(value, min_value, max_value) = min(max(value, min_value), max_value);
function short_angle_delta(delta) = delta > 180 ? delta - 360 : delta < -180 ? delta + 360 : delta;
