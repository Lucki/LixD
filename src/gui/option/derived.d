module gui.option.derived;

import std.conv;
import std.string; // strip

import file.useropt;
import graphic.internal;
import gui;
import gui.option;
import hardware.keyset;
import hardware.mouse; // allow clicks on label

class BoolOption : Option {
private:
    Checkbox _checkbox;
    UserOption!bool _userOption;
    bool     _execute;

public:
    this(Geom g, UserOption!bool opt)
    {
        assert (opt !is null);
        _userOption = opt;
        this(g, opt.descShort);
    }

    this(Geom g, string cap)
    {
        // Hack use of this class: I use it in Editor's skill window.
        // opt will be null there, you may not call load/saveValue then.
        _checkbox = new Checkbox(new Geom(0, 0, 20, 20));
        super(g, new Label(new Geom(30, 0, g.xlg - 30, g.yl), cap));
        addChild(_checkbox);
    }

    @property bool checked() const { return _checkbox.checked;     }
    @property bool checked(bool b) { return _checkbox.checked = b; }
    @property bool execute() const { return _execute;              }

    override void loadValue()
    {
        assert (_userOption);
        _checkbox.checked = _userOption.value;
    }

    override void saveValue()
    {
        assert (_userOption);
        _userOption.value = _checkbox.checked;
    }

    override string explain() const
    {
        assert (_userOption);
        return _userOption.descLong;
    }

protected:
    override void calcSelf()
    {
        _execute = _checkbox.execute;
        // Allow clicks on the label, not only on the tiny checkbox.
        if (isMouseHere) {
            _checkbox.down = mouseHeldLeft > 0;
            if (mouseReleaseLeft && ! _checkbox.execute) {
                _checkbox.toggle();
                _execute = true;
            }
        }
    }
}

// A hack class: the user option (pausedAssign) can take 3 values: 0, 1, 2.
// I offer only 1 and 2 for now, with a checkbox. That uses this class.
class BoolOptionOneOrTwo : BoolOption {
private:
    UserOption!int _userOption;

public:
    this(Geom g, UserOption!int opt)
    {
        super(g, "Unpause on skill assignment"); // hack hardcoded string
        _userOption = opt;
    }

    override void loadValue() { checked = (_userOption.value == 2); }
    override void saveValue() { _userOption.value = _checkbox.checked ? 2 : 1;}
    override string explain() const { return _userOption.descLong; }
}

class TextOption : Option {
private:
    Texttype _texttype;
    string*  _target;

public:
    this(Geom g, string cap, string* t)
    {
        assert (t);
        _texttype = new Texttype(new Geom(0, 0, mostButtonsXl, 20));
        super(g, new Label(new Geom(mostButtonsXl + spaceGuiTextX, 0,
                            g.xlg - mostButtonsXl + spaceGuiTextX, g.yl),
                            cap));
        addChild(_texttype);
        _target = t;
    }

    override void loadValue() { _texttype.text = *_target; }
    override void saveValue() { *_target = _texttype.text.strip; }

    // hack, to enable immediate check of nonempty
    @property inout(Texttype) texttype() inout { return _texttype; }
}



private void registerAtWatcher(KeyDuplicationWatcher watcher, KeyButton button)
{
    if (watcher is null || button is null)
        return;
    watcher.watch(button);
    button.onChange = () { watcher.checkForDuplicateBindings(); };
}

class HotkeyOption : Option {
private:
    MultiKeyButton _keyb;
    UserOption!KeySet _userOption;

public:
    // watcher may be null, then we won't register ourselves with any watcher
    this(Geom g, UserOption!KeySet opt, KeyDuplicationWatcher watcher = null)
    {
        assert (opt);
        _keyb = new MultiKeyButton(new Geom(0, 0, keyButtonXl, 20));
        super(g, new Label(new Geom(keyButtonXl + spaceGuiTextX, 0,
                            g.xlg - keyButtonXl + spaceGuiTextX, g.yl),
                            opt.descShort));
        addChild(_keyb);
        _userOption = opt;
        registerAtWatcher(watcher, _keyb);
    }

    override void loadValue() { _keyb.keySet = _userOption.value; }
    override void saveValue() { _userOption.value = _keyb.keySet; }
    override string explain() const { return _userOption.descLong; }
}

class SkillHotkeyOption : Option
{
    private SkillIcon _cb;
    private SingleKeyButton _keyb;
    private UserOption!KeySet _userOption;

    // watcher may be null, then we won't register ourselves with any watcher
    this(Geom g, Ac ac, UserOption!KeySet opt, KeyDuplicationWatcher watcher)
    {
        super(g);
        assert (opt);
        _keyb = new SingleKeyButton(new Geom(0, 0, xlg, 20, From.BOTTOM));
        _cb   = new SkillIcon(new Geom(0, 0, xlg, ylg-20, From.TOP));
        _cb.ac = ac;
        addChildren(_cb, _keyb);
        _userOption = opt;
        registerAtWatcher(watcher, _keyb);
    }

    override void loadValue() { _keyb.keySet = _userOption.value; }
    override void saveValue() { _userOption.value = _keyb.keySet; }
}



class NumPickOption : Option
{
    private NumPick _num;
    private UserOption!int _userOption;

    // hack, to enable immediate updates of the GUI menu colors
    public @property inout(NumPick) num() inout { return _num; }

    this(Geom g, NumPickConfig cfg, UserOption!int opt)
    {
        assert (opt);
        // Hack: sixButtons is used in the editor's view options window.
        // That NumPick selects colors. We hardcode that use case's xlg
        // here, and hope that nobody else needs to supply custom xlg.
        immutable plusXl = cfg.sixButtons ? 40 : 0;
        _num = new NumPick(new Geom(0, 0, mostButtonsXl + plusXl, 20), cfg);
        super(g, new Label(new Geom(mostButtonsXl + plusXl + spaceGuiTextX, 0,
                            g.xlg - mostButtonsXl + plusXl + spaceGuiTextX,
                            g.yl), opt.descShort));
        addChild(_num);
        _userOption = opt;
    }

    @property int  value()   const { return _num.number;     }
    @property bool execute() const { return _num.execute;    }
    override void loadValue() { _num.number = _userOption.value; }
    override void saveValue() { _userOption.value = _num.number; }
    override string explain() const { return _userOption.descLong; }
}



alias ResolutionOption = ManyNumbersOption!2;

class ManyNumbersOption (int fields) : Option
    if (fields >= 1) {

private:
    Texttype[fields] _texttype;
    UserOption!int[fields] _userOptions;

public:
    this(Geom g, UserOption!int[fields] targets...)
    {
        assert (targets[0]);
        super(g, new Label(new Geom(mostButtonsXl + spaceGuiTextX, 0,
                            g.xlg - mostButtonsXl + spaceGuiTextX, g.yl),
                            targets[0].descShort));
        foreach (i; 0 .. fields) {
            _texttype[i] = new Texttype(new Geom(
                i * mostButtonsXl/fields, 0, mostButtonsXl/fields, 20));
            _texttype[i].allowedChars = Texttype.AllowedChars.digits;
            addChild(_texttype[i]);
            assert (targets[i] !is null);
            _userOptions[i] = targets[i];
        }
    }

    override void loadValue()
    {
        foreach (i; 0 .. fields)
            _texttype[i].text = to!string(_userOptions[i].value);
    }

    override void saveValue()
    {
        foreach (i; 0 .. fields)
            _userOptions[i].value = _texttype[i].number;
    }

    override string explain() const { return _userOptions[0].descLong; }
}
