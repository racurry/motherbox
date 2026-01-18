// BOSL2 Test File
// This file verifies BOSL2 library is correctly installed and working
// Tests: include, attachments, shapes, boolean helpers

include <BOSL2/std.scad>

// Parameters
box_size = 30;
hole_radius = 8;
chamfer_size = 3;

// Test cuboid with chamfers and attachment system
diff()
cuboid([box_size, box_size, box_size], chamfer=chamfer_size, anchor=BOTTOM)
    // Test attach() with cylinder subtraction
    attach(TOP, BOT, inside=true, shiftout=0.01)
        cyl(h=box_size, r=hole_radius, $fn=50);

// Test prismoid (tapered shape)
back(box_size + 10)
    prismoid(size1=[20, 20], size2=[10, 10], h=15, anchor=BOTTOM);

// Test rect_tube (hollow rectangular tube)
fwd(box_size + 10)
    rect_tube(size=[25, 25], wall=3, h=20, anchor=BOTTOM);
