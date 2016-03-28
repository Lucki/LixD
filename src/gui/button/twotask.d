module gui.button.twotask;

/* class TwoTasksButton : BitmapButton
 * class SpawnIntButton : TwoTasksButton
 *
 * warm/hot have different meanings from class Button. Right now, both mean:
 * Don't execute continuously on LMB hold after a while.
 */

import basics.alleg5; // hotkeyNiceShort
import basics.globals; // bitmap file for the spawnint button, doubleclick spd
import graphic.cutbit;
import graphic.internal;
import gui;
import hardware.keyboard;
import hardware.mouse;

class TwoTasksButton : BitmapButton {

    this(Geom g, const(Cutbit) cb)
    {
        super(g, cb);
        whenToExecute = Button.WhenToExecute.whenMouseClickAllowingRepeats;
        // The default behavior for the left mouse button, therefore,
        // is like a spawn interval button. The right mouse function
        // always works like Button's whenMouseDown and can't be configured.
        // Setting whenToExecute configures the left mouse function only.
    }

    @property bool executeLeft()  const { return _executeLeft;  }
    @property bool executeRight() const { return _executeRight; }

    @property int hotkeyRight() const { return _hotkeyRight;     }
    @property int hotkeyRight(int i)  { return _hotkeyRight = i; }

    // forward/wrap Button methods for convenience
    @property int  hotkeyLeft() const { return hotkey;     }
    @property int  hotkeyLeft(int i)  { return hotkey = i; }

    override @property bool execute() const { return _executeLeft
                                                  || _executeRight; }
private:

    bool _executeLeft;
    bool _executeRight;

    int _hotkeyRight;

protected:

    override void calcSelf()
    {
        super.calcSelf();
        _executeLeft  = false;
        _executeRight = false;

        if (hidden)
            return;

        _executeLeft  = super.execute;
        _executeRight =
            isMouseHere && (mouseClickRight() || mouseHeldLongRight())
            || keyTappedAllowingRepeats(_hotkeyRight);

        down = keyHeld(hotkey) || keyHeld(_hotkeyRight)
            || (isMouseHere && (mouseHeldLeft || mouseHeldRight));
    }
    // end calcSelf

    override string hotkeyString() const
    {
        if (! hotkey && ! hotkeyRight) return null;
        if (! hotkeyRight)             return hotkeyNiceShort(hotkey);
        if (! hotkey)                  return hotkeyNiceShort(hotkeyRight);
        return hotkeyNiceShort(hotkey) ~ "/" ~ hotkeyNiceShort(hotkeyRight);
    }
}
// end class TwoTasksButton



class SpawnIntervalButton : TwoTasksButton {

public:

    this(Geom g)
    {
        super(g, getInternal(basics.globals.fileImageGamePanel2));
        Geom g2 = new Geom(g);
        g2.x   -= g.xl - 13;
        g2.from = From.CENTER;
        _label  = new Label(g2);
        addChild(_label);
    }

    @property int spawnint() const { return _spawnint; }

    @property int spawnint(in int i)
    {
        _spawnint = i;
        _label.number = _spawnint;
        reqDraw();
        return _spawnint;
    }

private:

    int   _spawnint;
    Label _label;

}
// end class SpawnIntervalButton