module mvc.v.gtk.output;

version (GTKApplication):

import gtk.ScrolledWindow;
import gtk.TextView;

@system:

final class Output: ScrolledWindow {
    private TextView _txtLog;

    invariant {
        assert(_txtLog !is null);
    }

    this() {
        auto txt = new TextView;
        super(txt);

        txt.setVexpand(true);
        txt.setSensitive(false);
        _txtLog = txt;
    }

    void appendText(string text) {
        _txtLog.appendText(text);
    }
}
