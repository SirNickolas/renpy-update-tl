module mvc.v.gtk.path_controls;

version (GTKApplication):

import gtk.Button;
import gtk.Entry;
import gtk.Grid;
import gtk.Image;
import gtk.Label;

@system:

enum PathControl: ubyte { renpySDK, project }

final class PathControls: Grid {
    private {
        Label[2] _labels;
        Button[2] _btns;
        Label[2] _labelsOut;
    }

    invariant {
        foreach (i; 0 .. 2) {
            assert(_labels[i] !is null);
            assert(_btns[i] !is null);
            assert(_labelsOut[i] !is null);
        }
    }

    this() {
        setRowSpacing(2);
        setColumnSpacing(6);

        foreach (i; 0 .. 2) {
            _labels[i] = new Label("");
            _labels[i].setXalign(.0);

            _btns[i] = new Button;
            _btns[i].setImage(new Image("document-open", IconSize.BUTTON));

            _labelsOut[i] = new Label("");
            _labelsOut[i].setXalign(.0);
            _labelsOut[i].setHexpand(true);
            _labelsOut[i].setSelectable(true);

            attach(_labels[i], 0, i, 1, 1);
            attach(_btns[i], 1, i, 1, 1);
            attach(_labelsOut[i], 2, i, 1, 1);
        }
    }

    void updateStrings() {
        import i18n: localize;

        _labels[0].setLabel(localize!q{MainWindow.renpySDKPath});
        _labels[1].setLabel(localize!q{MainWindow.projectPath});
    }

    void setValues(string renpySDKPath, string projectPath) {
        _labelsOut[0].setLabel(renpySDKPath !is null ? renpySDKPath : "");
        _labelsOut[1].setLabel(projectPath !is null ? projectPath : "");
    }

    void addOnClicked(PathControl which, void delegate(Button) @system handler) {
        _btns[which].addOnClicked(handler);
    }
}
