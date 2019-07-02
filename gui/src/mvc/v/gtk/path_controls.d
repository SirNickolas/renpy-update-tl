module mvc.v.gtk.path_controls;

version (GTKApplication):

import std.typecons: scoped;

import gdkpixbuf.Pixbuf;
import gtk.Button;
import gtk.Entry;
import gtk.Grid;
import gtk.Image;
import gtk.Label;

private @system:

package final class PathControls: Grid {
private:
    typeof(scoped!Label(""))[2] _labels;
    typeof(scoped!Button())[2] _btns;
    typeof(scoped!Entry())[2] _ents;

    public this() {
        setRowSpacing(2);
        setColumnSpacing(5);

        const string[2] captions = [
            "Ren'Py SDK path:",
            "Project path:",
        ];
        auto pixbuf = new Pixbuf(`views/img/document-open.png`);
        static foreach (i; 0 .. 2) {
            _labels[i] = scoped!Label(captions[i]);
            _labels[i].setXalign(.0);

            _btns[i] = scoped!Button();
            _btns[i].setImage(new Image(pixbuf));

            _ents[i] = scoped!Entry();
            _ents[i].setHexpand(true);
            _ents[i].setSensitive(false);

            attach(_labels[i], 0, i, 1, 1);
            attach(_btns[i], 1, i, 1, 1);
            attach(_ents[i], 2, i, 1, 1);
        }
    }
}
