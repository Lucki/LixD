module gui.button.key;

/* class SingleKeyButton:
 * You can assign several keys to this. If you click it, it will wait for a
 * hotkey assignment via keyboard or mouse, but then erase everything on it.
 * Multiple keys can only be assigned via this.keySet.
 *
 * class MultiKeyButton:
 * This has a SingleKeyButton as a component and manage its multiple keys.
 * If you click the SingleKeyButton component, you replace all of its keys with
 * one key, as described for KeyButton above. Click the '+' button to add
 * extras.
 */

import basics.alleg5; // timerTicks
import basics.globals; // ticksForDoubleClick
import graphic.color;
import gui;
import hardware.keyboard;
import hardware.keyset;
import hardware.mouse;

interface KeyButton {
    @property void onChange(void delegate());
    @property bool warnAboutDuplicateBindings() const;
    @property bool warnAboutDuplicateBindings(in bool);
    @property const(KeySet) keySet() const;
    @property const(KeySet) keySet(in KeySet);
}

class SingleKeyButton : TextButton, KeyButton {
private:
    KeySet _keySet;
    void delegate() _onChange; // called on new assignment, not on cancel
    bool _warnAboutDuplicateBindings; // only set externally, we don't check

public:
    this(Geom g) { super(g); }

    mixin (GetSetWithReqDraw!"warnAboutDuplicateBindings");

    @property const(KeySet) keySet() const { return _keySet; }
    @property const(KeySet) keySet(in KeySet sc)
    {
        if (sc == _keySet)
            return sc;
        _keySet = KeySet(sc);
        formatScancode();
        return sc;
    }

    @property void onChange(void delegate() f) { _onChange = f; }

    @property override bool on() const { return super.on(); }
    @property override bool on(in bool b)
    {
        if (b == on)
            return b;
        super.on(b);
        if (b) addFocus(this);
        else    rmFocus(this);
        return b;
    }

    @property override Alcol colorText() const
    {
        return _warnAboutDuplicateBindings ? color.red : super.colorText();
    }

protected:
    override void calcSelf()
    {
        super.calcSelf();
        if (! on)
            on = execute;
        else {
            if (mouseClickLeft)
                // Only LMB cancels this. RMB and MMB are assignable hotkeys.
                on = false;
            else if (scancodeTapped) {
                _keySet = KeySet(scancodeTapped);
                on = false;
                if (_onChange !is null)
                    _onChange();
            }
            formatScancode();
        }
    }

private:
    void formatScancode()
    {
        reqDraw();
        text = (on && timerTicks % 30 < 15)
            ? "\ufffd" // replacement char, question mark in a box
            : _keySet.nameLong;
    }
}

// ############################################################################

class MultiKeyButton : Element, KeyButton {
private:
    SingleKeyButton _big;
    TextButton _plus;
    TextButton _minus;
    KeySet _addTheseToBig; // Saves _big's keys when we click _plus
    void delegate() _onChange;

    enum plusXlg = 15f;

public:
    this(Geom g)
    {
        super(g);
        _big = new SingleKeyButton(new Geom(0, 0, xlg, ylg, From.RIGHT));
        _big.onChange = () { this.formatButtonsAndCallCallback(); };
        _plus = new TextButton(new Geom(plusXlg, 0, plusXlg, ylg), "+");
        _minus = new TextButton(new Geom(0, 0, plusXlg, ylg), "\u2212");
        addChildren(_big, _plus, _minus);
        keySet = KeySet();

        assert (! _onChange);
        formatButtonsAndCallCallback();
    }

    @property const(KeySet) keySet() const { return _big.keySet; }
    @property const(KeySet) keySet(in KeySet set)
    {
        if (_big.keySet == set)
            return set;
        _big.keySet = set;
        formatButtonsAndCallCallback();
        return set;
    }

    @property void onChange(void delegate() f) { _onChange = f; }

    @property bool warnAboutDuplicateBindings() const
    {
        return _big.warnAboutDuplicateBindings;
    }

    @property bool warnAboutDuplicateBindings(in bool b)
    {
        if (_big.warnAboutDuplicateBindings == b)
            return b;
        reqDraw();
        return _big.warnAboutDuplicateBindings = b;
    }

protected:
    override void calcSelf()
    {
        if (! _addTheseToBig.empty) {
            // Hack: We want _plus to be on until _big has seen a keypress.
            // Since _big takes focus, this.calcSelf() will only run after
            // _big loses focus. _plus.on = false here relies on this focus.
            _plus.on = false;
            keySet = KeySet(_big.keySet, _addTheseToBig);
            _addTheseToBig = KeySet();
        }
        if (_minus.execute) {
            assert (! keySet.empty);
            KeySet temp = keySet;
            temp.remove(temp.keysAsInts[$-1]);
            keySet = temp;
        }
        if (_plus.execute) {
            _addTheseToBig = _big.keySet;
            _plus.on = true;
            _big.on = true;
        }
    }

private:
    void formatButtonsAndCallCallback()
    {
        _minus.shown = keySet.len >= 1;
        _plus.shown = keySet.len >= 1 && keySet.len < 3;
        _big.resize(xlg - plusXlg * (_minus.shown + _plus.shown), ylg);
        if (_onChange !is null)
            _onChange();
    }
}
