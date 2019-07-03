module mvc.v.gtk.output;

version (GTKApplication):

import gtk.ScrolledWindow;
import gtk.TextView;

@system:

final class Output: ScrolledWindow {
    private {
        TextView _txtLog;
        size_t _newlines;
    }

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
        import std.algorithm.mutation: stripRight;
        import std.range.primitives: empty;
        import std.utf: byCodeUnit;

        const stripped = text.byCodeUnit().stripRight('\n').source;
        if (stripped.empty)
            _newlines += text.length;
        else {
            foreach (i; 0 .. _newlines >> 1)
                _txtLog.appendText("\n\n");
            if (_newlines & 0x1)
                _txtLog.appendText("\n");
            _txtLog.appendText(stripped);
            _newlines = text.length - stripped.length;
        }
    }
}
