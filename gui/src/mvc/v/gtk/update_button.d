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

        _btn = new Button("");
        _spinner = new Spinner;
        add(_btn);
        add(_spinner);
    }

    void updateStrings() {
        import i18n: localize;

        _btn.setLabel(localize!q{MainWindow.update});
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

    void addOnClicked(void delegate(Button) @system dg) {
        _btn.addOnClicked(dg);
    }
}
