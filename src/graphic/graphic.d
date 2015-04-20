module graphic.graphic;

/* A simple graphic object, i.e., an instance of Cutbit that is drawn to
 * a certain position on a torbit. This is not about graphic sets from L1,
 * ONML etc., see level/gra_set.h for that.
 */

import std.conv; // rounding double to int, and float coordinates to int
import std.math;

import basics.alleg5;
import basics.help;
import graphic.cutbit;
import graphic.torbit;

class Graphic {

    this(const Cutbit, Torbit, const int = 0, const int = 0);
    ~this() { }

    @property const(Cutbit) cutbit() const { return _cutbit; }

    @property AlBit  albit()               { return _cutbit.get_albit(); }
    @property Torbit ground(Torbit gr)     { return _ground = gr;        }
    @property inout(Torbit) ground() inout { return _ground;             }

    @property int x() const { return _x; }
    @property int y() const { return _y; }
//  @property int x(in int/float);
//  @property int y(in int/float);
    void set_xy(Tx, Ty)(Tx nx, Ty ny) { x = nx; y = ny; }

    @property bool        mirror  () const { return _mirror; }
    @property double      rotation() const { return _rot;    }
    @property Cutbit.Mode mode    () const { return _mode;   }
    @property bool        mirror  (bool b)        { return _mirror = b;       }
    @property double      rotation(double dbl)    { return _rot = fmod(dbl,4);}
    @property Cutbit.Mode mode    (Cutbit.Mode m) { return _mode = m;         }

    @property int xf() const { return xf; }
    @property int yf() const { return yf; }
    @property int xf(in int new_x_frame) { return _xf = new_x_frame; }
    @property int yf(in int new_y_frame) { return _yf = new_y_frame; }

/* Wrapper functions, these return things from the Cutbit class
 * If the Graphic object is rotated, get_xl()/yl() are NOT wrappers,
 * but rotate with the Graphic object before they access the Cutbit part.
 * Same thing with get_pixel().
 *
 *  int  get_xl() const
 *  int  get_yl() const
 */
    @property int x_frames() const { return cutbit.get_x_frames(); }
    @property int y_frames() const { return cutbit.get_y_frames(); }

/*  bool get_frame_exists(int, int) const
 *  AlCol get_pixel      (int, int) const -- remember to lock target!
 *
 *  bool is_last_frame() const
 *
 *  void draw() const
 *
 *      draw to the torbit, according to mirror and rotation
 *
 *  void draw_directly_to_screen() const
 *
 *      Ignore (Torbit ground) and mirr/rotat; and blit immediately to the
 *      screen. This should only be used to draw the mouse cursor.
 */

private:

    const(Cutbit) _cutbit;
    Torbit        _ground;

    int _x;
    int _y;
    bool         _mirror;
    double       _rot;
    Cutbit.Mode  _mode;

    int _xf;
    int _yf;



public:

this(
    const(Cutbit) cb,
    Torbit        gr,
    const int     new_x,
    const int     new_y
) {
    _cutbit = cb;
    _ground = gr;

    _x      = new_x;
    _y      = new_y;
    _mirror = false;
    _rot    = 0;
    _mode   = Cutbit.Mode.NORMAL;

    _xf = 0;
    _yf = 0;
}



@property int
x(in int i)
{
    _x = i;
    if (ground && ground.get_torus_x())
        _x = positive_mod(_x, ground.get_xl());
    return _x;
}

@property int
y(in int i)
{
    _y = i;
    if (ground && ground.get_torus_y())
        _y = positive_mod(_y, ground.get_yl());
    return _y;
}

@property int x(in float i) { return x(i.to!int); }
@property int y(in float i) { return y(i.to!int); }



@property int
xl() const
{
    return (_rot == 0 || _rot == 2) ? cutbit.get_xl() : cutbit.get_yl();
}
@property int
yl() const
{
    return (_rot == 0 || _rot == 2) ? cutbit.get_yl() : cutbit.get_xl();
}



bool is_last_frame() const
{
    return ! cutbit.get_frame_exists(_xf + 1, _yf);
}



bool get_frame_exists(in int which_xf, in int which_yf) const
{
    return cutbit.get_frame_exists(which_xf, which_yf);
}



AlCol get_pixel(in int gx, in int gy) const
{
    immutable int _xl = cutbit.get_xl();
    immutable int _yl = cutbit.get_yl();
    int use_x = gx;
    int use_y = gy;

    // If the rotation is a multiple of a quarter turn, rotate the values
    // with the Graphic object. If the rotation is a fraction, return
    // the value from the original bitmap (treated as unrotated).
    // Lix terrain can only be rotated in quarter turns.
    int rotation_integer = to!int(_rot);
    if (rotation_integer - _rot != 0) rotation_integer = 0;

    // DTODO: check if this works still correctly, after we have
    // rewritten this class using D properties instead of getters/setters
    switch (rotation_integer) {
        case 0: use_x = gx;       use_y = !_mirror ? gy       : _yl-gy-1;break;
        case 1: use_x = gy;       use_y = !_mirror ? _yl-gx-1 : gx;      break;
        case 2: use_x = _xl-gx-1; use_y = !_mirror ? _yl-gy-1 : gy;      break;
        case 3: use_x = _xl-gy-1; use_y = !_mirror ? gx       : _yl-gx-1;break;
        default: break;
    }
    return cutbit.get_pixel(xf, yf, use_x, use_y);
}



void draw()
{
    if (mode == Cutbit.Mode.NORMAL) {
        cutbit.draw(_ground, _x, _y, _xf, _yf, _mirror, _rot);
    }
    else {
        cutbit.draw(_ground, _x, _y, _mirror, to!int(_rot), _mode);
    }
}



void
draw_directly_to_screen() const
{
    cutbit.draw_directly_to_screen(_x, _y, _xf, _yf);
}

}
// end class
