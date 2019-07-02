module mvc.v.gtk.path_controls;

version (GTKApplication):

import gdkpixbuf.Pixbuf;
import gtk.Button;
import gtk.Entry;
import gtk.Grid;
import gtk.Image;
import gtk.Label;

@system:

final class PathControls: Grid {
    private {
        Button[2] _btns;
        Entry[2] _ents;
    }

    invariant {
        foreach (i; 0 .. 2) {
            assert(_btns[i] !is null);
            assert(_ents[i] !is null);
        }
    }

    this() {
        setRowSpacing(2);
        setColumnSpacing(6);

        const string[2] captions = [
            "Ren'Py SDK path:",
            "Project path:",
        ];
        auto pixbuf = new Pixbuf(`views/img/document-open.png`);
        foreach (i; 0 .. 2) {
            auto label = new Label(captions[i]);
            label.setXalign(.0);

            _btns[i] = new Button;
            _btns[i].setImage(new Image(pixbuf));

            _ents[i] = new Entry;
            _ents[i].setHexpand(true);
            _ents[i].setSensitive(false);

            attach(label, 0, i, 1, 1);
            attach(_btns[i], 1, i, 1, 1);
            attach(_ents[i], 2, i, 1, 1);
        }
    }

    void setValues(string renpySDKPath, string projectPath) {
        _ents[0].setText(renpySDKPath);
        _ents[1].setText(projectPath);
    }
}
