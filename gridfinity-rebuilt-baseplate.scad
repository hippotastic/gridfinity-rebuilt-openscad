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
include <src/core/gridfinity-baseplate-thin-snap-top.scad>
include <src/core/gridfinity-baseplate-thin-snap-side.scad>

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
// use a 45 degree chamfer to reduce bottom padding material in thin/minimal styles
efficient_bottom_padding = true;
// margin removed from each outside edge
outer_margin = 0.10; // [0:0.01:0.50]
/* [Filled Corners - Reduces radius of selected corners] */
fill_top_left_corner = false;
fill_top_right_corner = false;
fill_bottom_right_corner = false;
fill_bottom_left_corner = false;

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
style_plate = 3; // [0: thin, 1:weighted, 2:skeletonized, 3: screw together, 4: screw together minimal, 5: thin snap together top, 6: thin snap together side]
// hole styles
style_hole = 0; // [0:none, 1:countersink, 2:counterbore]

/* [Thin Snap Together Top Debug] */
// render the baseplate body
render_baseplate = true;
// render a standalone thin snap together connector
render_connector = false;
// render the standalone thin snap together connector cutout
render_cutout = false;
debug_top_snap_connector_in_baseplate = false;
debug_top_snap_connector_section = false;

/* [Magnet Hole] */
// Baseplate will have holes for 6mm Diameter x 2mm high magnets.
enable_magnet = true;
// Magnet holes will have crush ribs to hold the magnet.
crush_ribs = true;
// Magnet holes will have a chamfer to ease insertion.
chamfer_holes = true;

hole_options = bundle_hole_options(refined_hole=false, magnet_hole=enable_magnet, screw_hole=false, crush_ribs=crush_ribs, chamfer=chamfer_holes, supportless=false);

// ===== IMPLEMENTATION ===== //

// Main baseplate render path. The special style-5 debug branch renders a
// sectioned baseplate and connector overlay so the top-snap fit can be inspected
// in place without changing the exported production geometry.
if (render_baseplate) {
    if ($preview && style_plate == 5 && debug_top_snap_connector_section) {
        union() {
            color("tomato")
            render(convexity=10)
            difference() {
                gridfinityBaseplate([gridx, gridy], l_grid, [distancex, distancey], style_plate, hole_options, style_hole, [fitx, fity]);

                _thin_snap_top_debug_section_cutter(gridx, gridy, l_grid);
            }

            color("lightgray")
            render(convexity=10)
            difference() {
                _thin_snap_top_debug_connector_in_baseplate(gridx, gridy, l_grid);

                _thin_snap_top_debug_section_cutter(gridx, gridy, l_grid);
            }
        }
    } else {
        color("tomato")
        gridfinityBaseplate([gridx, gridy], l_grid, [distancex, distancey], style_plate, hole_options, style_hole, [fitx, fity]);

        if ($preview && style_plate == 5 && debug_top_snap_connector_in_baseplate) {
            color("lightgray")
            _thin_snap_top_debug_connector_in_baseplate(gridx, gridy, l_grid);
        }
    }
}

// Optional standalone positive connector. This is useful for test prints and
// for comparing the printed part against the negative cutout below.
if (render_connector) {
    color("lightgray") {
        if (style_plate == 5) {
            translate(_thin_snap_top_connector_standalone_translation())
            _thin_snap_top_connector();
        } else {
            translate(_thin_snap_side_connector_standalone_translation())
            _thin_snap_side_connector();
        }
    }
}

// Optional standalone negative cutout. It is translucent in preview so the
// connector can be visually checked against the clearance envelope.
if (render_cutout) {
    color("cornflowerblue", 0.4) {
        if (style_plate == 5) {
            translate(_thin_snap_top_cutout_standalone_translation())
            _thin_snap_top_connector_display(cutout=true);
        } else {
            translate(_thin_snap_side_cutout_standalone_translation())
            _thin_snap_side_connector_display(cutout=true);
        }
    }
}

// Preview-only overlay: show connector and cutout at the same origin instead of
// side by side. This makes fit offsets, chamfers, and clearance easier to judge.
if ($preview && render_connector && render_cutout) {
    if (style_plate == 5) {
        color("lightgray")
        _thin_snap_top_connector();

        color("cornflowerblue", 0.4)
        _thin_snap_top_connector_display(cutout=true);
    } else {
        color("lightgray")
        _thin_snap_side_connector();

        color("cornflowerblue", 0.4)
        translate([0, 0, _thin_snap_side_cutout_overlay_z_offset()])
        _thin_snap_side_connector_display(cutout=true);
    }
}

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
    assert(is_bool(efficient_bottom_padding),
        "efficient_bottom_padding must be true or false.");
    assert(outer_margin >= 0,
        "outer_margin may not be negative.");
    assert(is_bool(fill_top_left_corner),
        "fill_top_left_corner must be true or false.");
    assert(is_bool(fill_top_right_corner),
        "fill_top_right_corner must be true or false.");
    assert(is_bool(fill_bottom_right_corner),
        "fill_bottom_right_corner must be true or false.");
    assert(is_bool(fill_bottom_left_corner),
        "fill_bottom_left_corner must be true or false.");

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

    // Clockwise from top left, matching the filled-corner UI order.
    corner_points = [
        padding_start_point + [0, size_mm.y, 0],
        padding_start_point + [size_mm.x, size_mm.y, 0],
        padding_start_point + [size_mm.x, 0, 0],
        padding_start_point,
    ];
    filled_corner_radius = 0.5;
    corner_radii = [
        fill_top_left_corner ? filled_corner_radius : BASEPLATE_OUTER_RADIUS,
        fill_top_right_corner ? filled_corner_radius : BASEPLATE_OUTER_RADIUS,
        fill_bottom_right_corner ? filled_corner_radius : BASEPLATE_OUTER_RADIUS,
        fill_bottom_left_corner ? filled_corner_radius : BASEPLATE_OUTER_RADIUS
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
    snap_together_top = sp == 5;
    snap_together_side = sp == 6;
    snap_together = snap_together_top || snap_together_side;
    minimal = sp == 0 || sp == 4 || snap_together;

    _apply_bottom_padding(
        bottom_padding_delta,
        padding_start_point,
        size_mm,
        efficient_bottom_padding && (sp == 0 || snap_together),
        grid_size,
        length,
        baseplate_height_mm
    ) {
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
                radius = corner_radii[i];
                translate([
                    point.x + (radius * -sign(point.x)),
                    point.y + (radius * -sign(point.y)),
                    0
                ])
                rotate([0, 0, 90 - i*90])
                square_baseplate_corner(additional_height, true, radius);
            }

            if (screw_together) {
                translate([0, 0, additional_height/2])
                cutter_screw_together(grid_size.x, grid_size.y, length);
            }

            if (snap_together_top) {
                cutter_snap_together(grid_size.x, grid_size.y, length);
            }

            if (snap_together_side) {
                cutter_snap_together_side(grid_size.x, grid_size.y, length);
            }

            if (render_height_limit < baseplate_height_mm) {
                translate([padding_start_point.x - TOLLERANCE, padding_start_point.y - TOLLERANCE, render_height_limit])
                cube([
                    size_mm.x + 2*TOLLERANCE,
                    size_mm.y + 2*TOLLERANCE,
                    baseplate_height_mm - render_height_limit + TOLLERANCE
                ]);
            }

            if ($preview && snap_together_top && debug_top_snap_connector_section) {
                _thin_snap_top_debug_section_cutter(grid_size.x, grid_size.y, length);
            }
        }
    }
}

function calculate_offset(style_plate, enable_magnet, style_hole) =
    assert(style_plate >=0 && style_plate <=6)
    let (screw_together = style_plate == 3 || style_plate == 4)
    screw_together ? 6.75 :
    (style_plate==0 || style_plate==5 || style_plate==6) ? 0 :
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

module _apply_bottom_padding(
    bottom_padding_delta,
    start_point,
    size,
    efficient=false,
    grid_size=[0, 0],
    grid_length=l_grid,
    baseplate_height=BASEPLATE_HEIGHT
) {
    assert(is_num(bottom_padding_delta));
    assert(is_list(start_point) && len(start_point) == 3);
    assert(is_list(size) && len(size) == 3);
    assert(is_bool(efficient));
    assert(is_list(grid_size) && len(grid_size) == 2);
    assert(grid_length > 0);
    assert(baseplate_height >= BASEPLATE_HEIGHT);

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

            _extrude_bottom_padding(
                bottom_padding_delta,
                efficient,
                grid_size,
                grid_length,
                baseplate_height,
                start_point,
                size
            )
            children();
        }
    } else {
        children();
    }
}

module _extrude_bottom_padding(
    padding_height,
    efficient=false,
    grid_size=[0, 0],
    grid_length=l_grid,
    baseplate_height=BASEPLATE_HEIGHT,
    start_point=[0, 0, 0],
    size=[0, 0, 0]
) {
    assert(padding_height > 0);
    assert(is_bool(efficient));
    assert(is_list(grid_size) && len(grid_size) == 2);
    assert(grid_length > 0);
    assert(baseplate_height >= BASEPLATE_HEIGHT);
    assert(is_list(start_point) && len(start_point) == 3);
    assert(is_list(size) && len(size) == 3);

    if (efficient) {
        // The projected bottom-padding cutter starts this far inside each grid cell edge.
        // Expanding adjacent cell openings equally leaves target-width ribs between them.
        cell_hole_edge_inset = BASEPLATE_OUTER_RADIUS - BASEPLATE_INNER_RADIUS;
        rib_width_at_padding = 2*cell_hole_edge_inset;
        target_rib_width = 1.2;
        max_chamfer_height = max(0, (rib_width_at_padding - target_rib_width) / 2);
        // Small bottom radii keep the underside intersections close to a simple grid.
        bottom_corner_radius = target_rib_width / 2;

        // 45 degree chamfer: horizontal growth of each cell opening equals vertical height.
        chamfer_height = min(max_chamfer_height, padding_height);
        straight_height = padding_height - chamfer_height;

        // The chamfer cutters overlap at grid intersections. Pre-rendering only the bottom
        // padding boolean avoids OpenCSG preview artifacts without rendering the whole baseplate.
        render()
        difference() {
            translate([0, 0, -padding_height])
            linear_extrude(padding_height + TOLLERANCE)
            _bottom_padding_footprint()
            children();

            union() {
                if (straight_height > 0) {
                    translate([0, 0, -padding_height - TOLLERANCE])
                    linear_extrude(straight_height + 2*TOLLERANCE)
                    _bottom_padding_grid_holes(
                        grid_size,
                        grid_length,
                        baseplate_height,
                        start_point,
                        size,
                        target_rib_width,
                        chamfer_height,
                        max_chamfer_height,
                        bottom_corner_radius
                    );
                }

                if (chamfer_height > 0) {
                    _bottom_padding_grid_hole_chamfers(
                        grid_size,
                        grid_length,
                        baseplate_height,
                        chamfer_height,
                        max_chamfer_height,
                        start_point,
                        size,
                        target_rib_width,
                        bottom_corner_radius
                    );
                }
            }
        }
    } else {
        translate([0, 0, -padding_height])
        linear_extrude(padding_height + TOLLERANCE)
        _bottom_padding_footprint()
        children();
    }
}

module _bottom_padding_footprint(inset=0) {
    assert(inset >= 0);

    offset(delta=-inset)
    projection(cut=true)
    translate([0, 0, -LAYER_HEIGHT])
    children();
}

function _bottom_padding_cell_center(index, grid_size, grid_length) = [
    (-grid_size.x/2 + index.x + 0.5) * grid_length,
    (-grid_size.y/2 + index.y + 0.5) * grid_length
];

function _bottom_padding_growth_from_allowed(allowed, chamfer_height, max_chamfer_height) =
    max_chamfer_height == 0 ? 0
    : min(chamfer_height, max(0, allowed) * chamfer_height / max_chamfer_height);

function _bottom_padding_cell_growth(
    index,
    grid_size,
    grid_length,
    start_point,
    size,
    target_rib_width,
    chamfer_height,
    max_chamfer_height
) =
    let(
        center = _bottom_padding_cell_center(index, grid_size, grid_length),
        cell_hole_edge_inset = BASEPLATE_OUTER_RADIUS - BASEPLATE_INNER_RADIUS,
        hole_half_size = grid_length/2 - cell_hole_edge_inset,
        hole_min = center - [hole_half_size, hole_half_size],
        hole_max = center + [hole_half_size, hole_half_size],
        outer_min = [start_point.x + target_rib_width, start_point.y + target_rib_width],
        outer_max = [
            start_point.x + size.x - target_rib_width,
            start_point.y + size.y - target_rib_width
        ]
    )
    [
        _bottom_padding_growth_from_allowed(hole_min.x - outer_min.x, chamfer_height, max_chamfer_height),
        _bottom_padding_growth_from_allowed(outer_max.x - hole_max.x, chamfer_height, max_chamfer_height),
        _bottom_padding_growth_from_allowed(hole_min.y - outer_min.y, chamfer_height, max_chamfer_height),
        _bottom_padding_growth_from_allowed(outer_max.y - hole_max.y, chamfer_height, max_chamfer_height)
    ];

function _bottom_padding_corner_arc(center, radius, start_angle, end_angle, steps) =
    radius <= 0
        ? [center]
        : arc_points(center, radius, start_angle, end_angle, steps);

function _bottom_padding_rounded_rect_points(size, radius, steps=8) =
    let(
        raw_radii = is_list(radius) ? radius : [radius, radius, radius, radius],
        max_radius = max(0, min(size) / 2 - TOLLERANCE),
        r = [for (corner_radius = raw_radii) min(corner_radius, max_radius)],
        hw = size.x / 2,
        hh = size.y / 2
    )
    concat(
        _bottom_padding_corner_arc([hw - r[0], -hh + r[0]], r[0], -90, 0, steps),
        _bottom_padding_corner_arc([hw - r[1], hh - r[1]], r[1], 0, 90, steps),
        _bottom_padding_corner_arc([-hw + r[2], hh - r[2]], r[2], 90, 180, steps),
        _bottom_padding_corner_arc([-hw + r[3], -hh + r[3]], r[3], 180, 270, steps)
    );

function _bottom_padding_outer_corner_hole_radius(outer_rib_width, default_radius) =
    BASEPLATE_OUTER_RADIUS > outer_rib_width
        ? BASEPLATE_OUTER_RADIUS - outer_rib_width
        : default_radius;

function _bottom_padding_cell_corner_radii(
    index,
    grid_size,
    default_radius,
    outer_rib_width
) =
    let(
        outer_corner_radius = _bottom_padding_outer_corner_hole_radius(
            outer_rib_width,
            default_radius
        )
    )
    // Ordered like _bottom_padding_rounded_rect_points: BR, TR, TL, BL.
    [
        index.x == grid_size.x - 1 && index.y == 0 && !fill_bottom_right_corner
            ? outer_corner_radius : default_radius,
        index.x == grid_size.x - 1 && index.y == grid_size.y - 1 && !fill_top_right_corner
            ? outer_corner_radius : default_radius,
        index.x == 0 && index.y == grid_size.y - 1 && !fill_top_left_corner
            ? outer_corner_radius : default_radius,
        index.x == 0 && index.y == 0 && !fill_bottom_left_corner
            ? outer_corner_radius : default_radius
    ];

module _bottom_padding_cell_hole(
    grid_length,
    growth=[0, 0, 0, 0],
    corner_radius=BASEPLATE_INNER_RADIUS
) {
    assert(grid_length > 0);
    assert(is_list(growth) && len(growth) == 4);
    assert(min(growth) >= 0);
    assert(is_list(corner_radius) ? len(corner_radius) == 4 : corner_radius >= 0);
    assert(is_list(corner_radius) ? min(corner_radius) >= 0 : true);

    top_size = baseplate_inner_size([grid_length, grid_length]);
    grown_size = top_size + [growth[0] + growth[1], growth[2] + growth[3]];
    offset = [(growth[1] - growth[0]) / 2, (growth[3] - growth[2]) / 2];

    translate(offset)
    polygon(_bottom_padding_rounded_rect_points(grown_size, corner_radius));
}

module _bottom_padding_grid_hole_chamfers(
    grid_size,
    grid_length,
    baseplate_height,
    chamfer_height,
    max_chamfer_height,
    start_point=[0, 0, 0],
    size=[0, 0, 0],
    outer_rib_width=0,
    bottom_corner_radius=0
) {
    assert(is_list(grid_size) && len(grid_size) == 2);
    assert(grid_length > 0);
    assert(baseplate_height >= BASEPLATE_HEIGHT);
    assert(chamfer_height >= 0);
    assert(max_chamfer_height >= 0);
    assert(is_list(start_point) && len(start_point) == 3);
    assert(is_list(size) && len(size) == 3);
    assert(outer_rib_width >= 0);
    assert(bottom_corner_radius >= 0);

    for (x = [0:grid_size.x-1]) {
        for (y = [0:grid_size.y-1]) {
            index = [x, y];
            center = _bottom_padding_cell_center(index, grid_size, grid_length);
            growth = _bottom_padding_cell_growth(
                index,
                grid_size,
                grid_length,
                start_point,
                size,
                outer_rib_width,
                chamfer_height,
                max_chamfer_height
            );
            corner_radii = _bottom_padding_cell_corner_radii(
                index,
                grid_size,
                bottom_corner_radius,
                outer_rib_width
            );

            translate(center)
            hull() {
                translate([0, 0, -chamfer_height])
                linear_extrude(TOLLERANCE)
                _bottom_padding_cell_hole(
                    grid_length,
                    growth,
                    corner_radii
                );

                translate([0, 0, -TOLLERANCE])
                linear_extrude(TOLLERANCE)
                _bottom_padding_cell_hole(grid_length);
            }
        }
    }
}

module _bottom_padding_grid_holes(
    grid_size,
    grid_length,
    baseplate_height,
    start_point=[0, 0, 0],
    size=[0, 0, 0],
    target_rib_width=0,
    chamfer_height=0,
    max_chamfer_height=0,
    bottom_corner_radius=0
) {
    assert(is_list(grid_size) && len(grid_size) == 2);
    assert(grid_length > 0);
    assert(baseplate_height >= BASEPLATE_HEIGHT);
    assert(is_list(start_point) && len(start_point) == 3);
    assert(is_list(size) && len(size) == 3);
    assert(target_rib_width >= 0);
    assert(chamfer_height >= 0);
    assert(max_chamfer_height >= 0);
    assert(bottom_corner_radius >= 0);

    for (x = [0:grid_size.x-1]) {
        for (y = [0:grid_size.y-1]) {
            index = [x, y];
            center = _bottom_padding_cell_center(index, grid_size, grid_length);
            growth = _bottom_padding_cell_growth(
                index,
                grid_size,
                grid_length,
                start_point,
                size,
                target_rib_width,
                chamfer_height,
                max_chamfer_height
            );
            corner_radii = _bottom_padding_cell_corner_radii(
                index,
                grid_size,
                bottom_corner_radius,
                target_rib_width
            );

            translate(center)
            _bottom_padding_cell_hole(grid_length, growth, corner_radii);
        }
    }
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
