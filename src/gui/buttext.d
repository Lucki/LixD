module gui.buttext;

/* A button with text printed on it.
 *
 * The button may have a checkmark on its right-hand side. If present, the
 * maximal length for the text is shortened. Set check_frame != 0 to get it.
 */

import std.conv;

import gui;
import basics.globals;
import graphic.cutbit;
import graphic.gralib;

class TextButton : Button {

    this(Geom g)
    {
        super(g);
        // the text should not be drawn on the 3D part of the button, but only
        // to the uniformly colored center. Each side has a thickness of 2.
        // The checkmark already accounts for this.
        // The checkmark is at the right of the button, for all text aligns.
        alias th  = Geom.thickg;
        alias lef = Geom.From.LEFT;
        alias ctr = Geom.From.CENTER;
        left         = new Label(new Geom(th, 0, g.xl - 2*th,      0, lef));
        left_check   = new Label(new Geom(th, 0, g.xl - th-ch_xlg, 0, lef));
        center       = new Label(new Geom(0,  0, g.xl - 2*th,      0, ctr));
        center_check = new Label(new Geom(0,  0, g.xl - 2*ch_xlg,  0, ctr));

        check_geom = new Geom(0, 0, ch_xlg, ch_xlg, Geom.From.RIGHT);
        check_geom.parent = this.geom;

        add_children(left, left_check, center, center_check);
    }

    bool align_left() const { return _align_left;                          }
    bool align_left(bool b) { _align_left = b; prep(); return _align_left; }

    string text() const      { return _text;                }
    string text(in string s) { _text = s; prep(); return s; }

    int check_frame() const { return _check_frame;                           }
    int check_frame(int i)  { _check_frame = i; prep(); return _check_frame; }

private:

    string _text;
    bool   _align_left;
    int    _check_frame; // frame 0 is empty, then don't draw anything and
                         // don't shorten the text maximal length
    Label left;
    Label left_check;
    Label center;
    Label center_check;

    Geom  check_geom;

    static immutable ch_xlg = 20; // size in geoms of checkbox



// need to move these rendering methods into something in Element, such that
// it's NVI-conformally called by req_draw(); -- or maybe not, since these
// are pretty complex with the text rendering, which is unnecessary at click
private void
prep()
{
    req_draw();
    foreach (label; [ left, left_check, center, center_check ]) {
        label.text = "";
    }
    switch (_align_left * 2 + (_check_frame != 0)) {
        case 0: center      .text = _text; break;
        case 1: center_check.text = _text; break;
        case 2: left        .text = _text; break;
        case 3: left_check  .text = _text; break;
        default: assert (false);
    }
}



protected override void
draw_self()
{
    super.draw_self();

    // Draw the checkmark, which doesn't overlap with the children.
    // There's a (ch_xlg) x (ch_xlg) area reserved for the cutbit on the right.
    // Draw to the center of this square.
    if (_check_frame != 0) {
        auto cb = get_internal(file_bitmap_menu_checkmark);
        cb.draw(guiosd,
            to!int(check_geom.xs + check_geom.xls/2 - cb.get_xl()/2),
            to!int(check_geom.ys + check_geom.yls/2 - cb.get_xl()/2),
            _check_frame, 2 * (get_on() && ! get_down())
        );
    }
}

}; // Klassenende
