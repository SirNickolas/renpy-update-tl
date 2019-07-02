module mvc.v.gtk.app;

version (GTKApplication):

import std.typecons: Flag, Yes, No, BlackHole, scoped;

import gtk.Box;
import gtk.Main;
import gtk.MainWindow;

import mvc.m.data: Lang, Model;
import mvc.v.gtk.output;
import mvc.v.gtk.path_controls;
import mvc.v.gtk.langs;
import mvc.v.iface;

private @system:

package final class MyWindow: MainWindow {
private:
    typeof(scoped!Box(Orientation.VERTICAL, 0)) _vbox;
    typeof(scoped!PathControls()) _pathControls;
    typeof(scoped!Languages()) _languages;
    typeof(scoped!Output()) _output;

    public this() {
        import version_;

        enum title = "Ren'Py translation updater (v" ~ programVersion ~ ')';
        enum height = 500;
        enum width = cast(int)(height * 1.618);
        super(title);
        setSizeRequest(width, height);
        setBorderWidth(7);

        _pathControls = scoped!PathControls();
        _languages = scoped!Languages();
        _output = scoped!Output();

        _vbox = scoped!Box(Orientation.VERTICAL, 5);
        _vbox.add(_pathControls);
        _vbox.add(_languages);
        _vbox.add(_output);
        add(_vbox);
    }
}

public final class Application: BlackHole!IView {
    private typeof(scoped!MyWindow()) _window;

    this() {
        _window = scoped!MyWindow();
    }

    void show() {
        _window.showAll();
    }
}

public Application createApplication(string[ ] args) {
    Main.init(args);
    return new Application;
}

public int runApplication(Application app) {
    app.show();
    Main.run();
    return 0;
}
