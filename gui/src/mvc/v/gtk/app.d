module mvc.v.gtk.app;

version (GTKApplication):

import std.typecons: Flag, Yes, No, BlackHole, scoped;

import gtk.Box;
import gtk.Main;
import gtk.MainWindow;

import mvc.m.data: Model;
import mvc.v.gtk.langs;
import mvc.v.gtk.output;
import mvc.v.gtk.path_controls;
import mvc.v.gtk.update_button;
import mvc.v.iface;

private @system:

package final class MyWindow: MainWindow {
private:
    PathControls _pathControls;
    Languages _languages;
    UpdateButton _updateBtn;
    Output _output;

    invariant {
        assert(_pathControls !is null);
        assert(_languages !is null);
        assert(_updateBtn !is null);
        assert(_output !is null);
    }

    public this() {
        import version_;

        enum title = "Ren'Py translation updater (v" ~ programVersion ~ ')';
        enum height = 500;
        enum width = cast(int)(height * 1.618);
        super(title);
        setSizeRequest(width, height);
        setBorderWidth(7);

        _pathControls = new PathControls;
        _languages = new Languages;
        _updateBtn = new UpdateButton;
        _output = new Output;

        auto vbox = new Box(Orientation.VERTICAL, 5);
        vbox.add(_pathControls);
        vbox.add(_languages);
        vbox.add(_updateBtn);
        vbox.add(_output);
        add(vbox);
    }
}

public final class Application: BlackHole!IView {
    private {
        typeof(scoped!MyWindow()) _window;
        IViewListener _listener;
    }

    this() {
        _window = scoped!MyWindow();
    }

    override typeof(this) setListener(IViewListener listener) nothrow pure @safe @nogc {
        _listener = listener;
        return this;
    }

    override void update(ref const Model model) {
        _window._pathControls.setValues(model.renpySDKPath, model.projectPath);
        _window._languages.update(model.langs, model.busy);
        _window._updateBtn.setSensitive(!model.busy);
        _window._updateBtn.setInProgress(!!model.running);
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
