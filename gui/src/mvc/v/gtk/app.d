module mvc.v.gtk.app;

version (GTKApplication):

import std.typecons: Flag, scoped;

import gtk.Box;
import gtk.Button;
import gtk.Main;
import gtk.MainWindow;

import mvc.m.data: Model;
import mvc.v.gtk.langs;
import mvc.v.gtk.output;
import mvc.v.gtk.path_controls;
import mvc.v.gtk.update_button;
import mvc.v.iface;

@system:

private final class _MyWindow: MainWindow {
    PathControls pathControls;
    Languages languages;
    UpdateButton updateBtn;
    Output output;

    invariant {
        assert(pathControls !is null);
        assert(languages !is null);
        assert(updateBtn !is null);
        assert(output !is null);
    }

    this() {
        import version_;

        enum title = "Ren'Py translation updater (v" ~ programVersion ~ ')';
        enum height = 500;
        enum width = cast(int)(height * 1.618);
        super(title);
        setSizeRequest(width, height);
        setBorderWidth(7);

        pathControls = new PathControls;
        languages = new Languages;
        updateBtn = new UpdateButton;
        output = new Output;

        auto vbox = new Box(Orientation.VERTICAL, 5);
        vbox.add(pathControls);
        vbox.add(languages);
        vbox.add(updateBtn);
        vbox.add(output);
        add(vbox);
    }
}

final class GTKView: IView {
    private {
        typeof(scoped!_MyWindow()) _window;
        IViewListener _listener;

        void _hndBtnRenpySDKClick(Button _) {
            if (_listener !is null)
                _listener.onBtnRenpySDKClick(this);
        }

        void _hndBtnProjectClick(Button _) {
            if (_listener !is null)
                _listener.onBtnProjectClick(this);
        }

        void _hndLangCheck(size_t index, bool active) {
            if (_listener !is null)
                _listener.onLangCheck(this, index, active);
        }

        void _hndEntLangFocusOut(size_t index, string text) {
            if (_listener !is null)
                _listener.onEntLangFocusOut(this, index, text);
        }

        void _hndBtnAddLangClick(Button _) {
            if (_listener !is null)
                _listener.onBtnAddLangClick(this);
        }

        void _hndBtnUpdateClick(Button _) {
            if (_listener !is null)
                _listener.onBtnUpdateClick(this);
        }
    }

    this() {
        _window = scoped!_MyWindow();
        _window.pathControls.addOnClicked(PathControl.renpySDK, &_hndBtnRenpySDKClick);
        _window.pathControls.addOnClicked(PathControl.project, &_hndBtnProjectClick);
        _window.languages.setOnClicked(&_hndLangCheck);
        _window.languages.setOnFocusOut(&_hndEntLangFocusOut);
        _window.languages.addOnAddClicked(&_hndBtnAddLangClick);
        _window.updateBtn.addOnClicked(&_hndBtnUpdateClick);
    }

    typeof(this) setListener(IViewListener listener) nothrow pure @safe @nogc {
        _listener = listener;
        return this;
    }

    void update(ref const Model model) {
        _window.pathControls.setValues(model.renpySDKPath, model.projectPath);
        _window.languages.update(model.langs, model.busy);
        _window.updateBtn.setSensitive(!model.busy);
        _window.updateBtn.setInProgress(!!model.running);
    }

    void focusLang(Flag!q{checkbox} checkbox, size_t index)
    in {
        assert(index <= int.max);
    }
    do {
        _window.languages.focus(checkbox, cast(uint)index);
    }

    private string _selectDirectory(string title, string initial) {
        import std.range.primitives: empty;
        import gtk.FileChooserDialog;

        string[1] buttonsText = ["Select"];
        ResponseType[1] responses = [ResponseType.ACCEPT];
        auto dlg = scoped!FileChooserDialog(
            title,
            _window,
            FileChooserAction.SELECT_FOLDER,
            buttonsText[ ],
            responses[ ],
        );
        scope(exit) dlg.destroy();
        dlg.setCreateFolders(false);
        if (!initial.empty)
            dlg.setCurrentFolder(initial);
        return dlg.run() == ResponseType.ACCEPT ? dlg.getFilename() : "";
    }

    void selectDirectory(
        string title,
        string initial,
        void delegate(IView, string) @system callback,
    ) {
        import std.range.primitives: empty;
        import glib.CharacterSet;

        auto path = _selectDirectory(title, initial);
        if (!path.empty) {
            size_t bytesRead, bytesWritten;
            path = CharacterSet.filenameToUtf8(path, path.length, bytesRead, bytesWritten);
        }
        callback(this, path);
    }

    void showWarning(string title, string text) {
        import gtk.MessageDialog;

        auto dlg = scoped!MessageDialog(
            _window,
            DialogFlags.DESTROY_WITH_PARENT,
            MessageType.WARNING,
            ButtonsType.CLOSE,
            text,
        );
        scope(exit) dlg.destroy();
        dlg.setTitle(title);
        dlg.run();
    }

    void appendToLog(string text) {
        _window.output.appendText(text);
    }

    void startAsyncWatching() const nothrow pure @safe @nogc { }
    void stopAsyncWatching() const nothrow pure @safe @nogc { }

    void executeInMainThread(void delegate(IView) @system dg) {
        import glib.Idle;

        new Idle({ dg(this); return false; });
    }

    void show() {
        _window.showAll();
    }
}

GTKView createApplication(string[ ] args) {
    Main.init(args);
    return new GTKView;
}

int runApplication(GTKView app) {
    app.show();
    Main.run();
    return 0;
}
