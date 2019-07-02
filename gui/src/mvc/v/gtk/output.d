module mvc.v.gtk.output;

version (GTKApplication):

import std.typecons: scoped;

import gtk.Box;
import gtk.Button;
import gtk.ScrolledWindow;
import gtk.Spinner;
import gtk.TextView;

private @system:

package final class Output: Box {
private:
    typeof(scoped!Box(Orientation.HORIZONTAL, 0)) _hbox;
    typeof(scoped!Button()) _btnUpdate;
    typeof(scoped!Spinner()) _spinner;
    typeof(scoped!ScrolledWindow()) _scrolled;
    TextView _txtLog;

    public this() {
        super(Orientation.VERTICAL, 5);

        _hbox = scoped!Box(Orientation.HORIZONTAL, 5);
        _btnUpdate = scoped!Button("Update");
        _spinner = scoped!Spinner();
        _hbox.add(_btnUpdate);
        _hbox.add(_spinner);
        add(_hbox);

        _txtLog = new TextView;
        _txtLog.setVexpand(true);
        _txtLog.setSensitive(false);

        _scrolled = scoped!ScrolledWindow(_txtLog);
        add(_scrolled);

        debug {
            bool b;
            _btnUpdate.addOnClicked((Button btn) {
                b = !b;
                if (b) {
                    _txtLog.appendText("Wait a few seconds, please…\n");
                    _spinner.start();
                } else {
                    _txtLog.appendText("Done.\n\n");
                    _spinner.stop();
                }
            });
        }
    }
}
