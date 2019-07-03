module mvc.v.gtk.langs;

version (GTKApplication):

import std.typecons: Flag;

import gdk.Event;
import gtk.Box;
import gtk.Button;
import gtk.CheckButton;
import gtk.Entry;
import gtk.Frame;
import gtk.Grid;
import gtk.Image;
import gtk.Widget;

import mvc.m.data: Lang;

@system:

final class Languages: Box {
private:
    Grid _grid;
    Button _btnAdd;
    uint _count;
    void delegate(size_t, bool) @system _onClicked;
    void delegate(size_t, string) @system _onFocusOut;

    invariant {
        assert(_grid !is null);
        assert(_btnAdd !is null);
        assert(_count <= int.max);
    }

    public this() {
        super(Orientation.HORIZONTAL, 0);

        _grid = new Grid;
        _grid.setBorderWidth(6);
        _grid.setRowSpacing(2);

        _btnAdd = new Button;
        _btnAdd.setImage(new Image(`views/img/plus-12.png`));
        _grid.attach(_btnAdd, 0, 0, 1, 1);

        auto frame = new Frame(_grid, "Languages");
        frame.setLabelAlign(.06, .5);
        add(frame);
    }

    int _getIndex(Widget widget, int column) {
        import std.algorithm.searching;
        import std.range;

        return iota(_count).find!(i => _grid.getChildAt(column, i) is widget).front;
    }

    void _hndBtnClicked(Button btn) {
        if (_onClicked !is null)
            _onClicked(_getIndex(btn, 0), (cast(CheckButton)btn).getActive());
    }

    bool _hndEntFocusOut(Event _, Widget ent) {
        if (_onFocusOut !is null)
            _onFocusOut(_getIndex(ent, 1), (cast(Entry)ent).getText());
        return false;
    }

    void _setCount(uint n)
    out {
        assert(_count == n);
        assert(_grid.getChildAt(0, _count) is _btnAdd);
    }
    do {
        if (n > _count)
            foreach (i; _count .. n) {
                _grid.insertRow(i);

                auto chkbx = new CheckButton;
                chkbx.setHalign(Align.CENTER);
                chkbx.addOnClicked(&_hndBtnClicked);
                _grid.attach(chkbx, 0, i, 1, 1);
                chkbx.show();

                auto ent = new Entry;
                ent.addOnFocusOut(&_hndEntFocusOut);
                _grid.attach(ent, 1, i, 1, 1);
                ent.show();
            }
        else if (n < _count)
            foreach_reverse (i; n .. _count)
                _grid.removeRow(i);
        else
            return;
        _count = n;
    }

    public void update(const(Lang)[ ] langs, bool busy) {
        const dg = _onClicked;
        _onClicked = null;
        scope(exit) _onClicked = dg;

        _setCount(cast(uint)langs.length);
        foreach (i, ref lang; langs) {
            auto chkbx = cast(CheckButton)_grid.getChildAt(0, cast(int)i);
            auto ent = cast(Entry)_grid.getChildAt(1, cast(int)i);
            chkbx.setActive(lang.enabled);
            chkbx.setSensitive(!busy);
            ent.setText(lang.name !is null ? lang.name : "");
            ent.setSensitive(!busy && lang.enabled && lang.ephemeral);
        }
        _btnAdd.setSensitive(!busy);
    }

    public void focus(Flag!q{checkbox} checkbox, uint index)
    in {
        assert(index < _count);
    }
    do {
        _grid.getChildAt(1 - checkbox, index).grabFocus();
    }

    public void setOnClicked(void delegate(size_t, bool) @system dg) {
        _onClicked = dg;
    }

    public void setOnFocusOut(void delegate(size_t, string) @system dg) {
        _onFocusOut = dg;
    }

    public void addOnAddClicked(void delegate(Button) @system dg) {
        _btnAdd.addOnClicked(dg);
    }
}
