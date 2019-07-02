module mvc.v.gtk.langs;

version (GTKApplication):

import std.typecons: scoped;

import gtk.Box;
import gtk.Button;
import gtk.CheckButton;
import gtk.Entry;
import gtk.Frame;
import gtk.Grid;
import gtk.Image;

import mvc.m.data: Lang;

private @system:

package final class Languages: Box {
private:
    typeof(scoped!Frame("")) _frame;
    typeof(scoped!Grid()) _grid;
    typeof(scoped!Button()) _btnAdd;
    int _count;

    invariant {
        assert(_count >= 0);
    }

    public this() {
        super(Orientation.HORIZONTAL, 0);

        _grid = scoped!Grid();
        _grid.setBorderWidth(6);
        _grid.setRowSpacing(2);

        _btnAdd = scoped!Button();
        _btnAdd.setImage(new Image(`views/img/plus-12.png`));
        _grid.attach(_btnAdd, 0, 0, 1, 1);

        _frame = scoped!Frame(_grid, "Languages");
        _frame.setLabelAlign(.06, .5);
        add(_frame);

        debug _setCount(3);
    }

    void _setCount(int n)
    out {
        assert(_count == n);
    }
    do {
        if (n > _count)
            foreach (i; _count .. n) {
                _grid.insertRow(i);

                auto chkbx = new CheckButton;
                chkbx.setHalign(Align.CENTER);
                _grid.attach(chkbx, 0, i, 1, 1);

                _grid.attach(new Entry, 1, i, 1, 1);
            }
        else if (n < _count)
            foreach_reverse (i; n .. _count)
                _grid.removeRow(i);
        else
            return;
        _count = n;
    }

    public void update(const(Lang)[ ] langs, bool busy) {
        _setCount(cast(int)langs.length);
        foreach (i, ref lang; langs) {
            auto chkbx = cast(CheckButton)_grid.getChildAt(0, cast(int)i);
            auto ent = cast(Entry)_grid.getChildAt(1, cast(int)i);
            chkbx.setActive(lang.enabled);
            chkbx.setSensitive(!busy);
            ent.setText(lang.name);
            ent.setSensitive(!busy && lang.enabled && lang.ephemeral);
        }
        _btnAdd.setSensitive(!busy);
    }
}
