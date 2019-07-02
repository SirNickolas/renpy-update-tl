module mvc.v.gtk.update_button;

version (GTKApplication):

import gtk.Box;
import gtk.Button;
import gtk.Spinner;

@system:

final class UpdateButton: Box {
    private {
        Button _btn;
        Spinner _spinner;
    }

    invariant {
        assert(_btn !is null);
        assert(_spinner !is null);
    }

    this() {
        super(Orientation.HORIZONTAL, 12);

        _btn = new Button("Update");
        _spinner = new Spinner;
        add(_btn);
        add(_spinner);

        debug {
            bool b;
            _btn.addOnClicked((Button btn) {
                b = !b;
                setInProgress(b);
            });
        }
    }

    override bool getSensitive() {
        return _btn.getSensitive();
    }

    override bool isSensitive() {
        return _btn.isSensitive();
    }

    override void setSensitive(bool value) {
        _btn.setSensitive(value);
    }

    void setInProgress(bool value) {
        if (value)
            _spinner.start();
        else
            _spinner.stop();
    }
}
