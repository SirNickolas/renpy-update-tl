module mvc.v.gtk.app;

version (GTKApplication):

import std.typecons: Flag, scoped;

import gtk.Box;
import gtk.Button;
import gtk.Main;
import gtk.MainWindow;

import i18n: Language;
import mvc.m.data: Model;
import mvc.v.gtk.langs;
import mvc.v.gtk.main_menu;
import mvc.v.gtk.output;
import mvc.v.gtk.path_controls;
import mvc.v.gtk.update_button;
import mvc.v.iface;

@system:

private final class _MyWindow: MainWindow {
    MainMenu menu;
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
        import mvc.v.gtk.res;

        enum height = 500;
        enum width = cast(int)(height * 1.618);
        super("");
        setIcon(createPixbufFromResource!`img/ab.png`());
        setSizeRequest(width, height);

        menu = new MainMenu;
        pathControls = new PathControls;
        languages = new Languages;
        updateBtn = new UpdateButton;
        output = new Output;

        auto vbox = new Box(Orientation.VERTICAL, 5);
        vbox.setMarginLeft(7);
        vbox.setMarginRight(7);
        vbox.setMarginBottom(7);
        vbox.add(menu);
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

        void _hndAboutSelected() {
            import std.format: format;
            import gtk.MessageDialog;
            import i18n: localize;
            import version_;

            auto dlg = scoped!MessageDialog(
                _window,
                DialogFlags.DESTROY_WITH_PARENT,
                MessageType.INFO,
                ButtonsType.CLOSE,
                true,
                localize!q{About.text}.format(programVersion),
            );
            scope(exit) dlg.destroy();
            dlg.setTitle(localize!q{About.title});
            dlg.run();
        }

        void _hndLanguageSelected(Language* language) {
            if (_listener !is null)
                _listener.onLanguageSelected(this, language);
        }

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
        _window.menu.setOnAboutSelected(&_hndAboutSelected);
        _window.menu.setOnLanguageSelected(&_hndLanguageSelected);
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

    void updateStrings() {
        import i18n: localize;

        _window.setTitle(localize!q{MainWindow.title});
        _window.menu.updateStrings();
        _window.pathControls.updateStrings();
        _window.languages.updateStrings();
        _window.updateBtn.updateStrings();
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
        import i18n: localize;

        string[1] buttonsText = [localize!q{FileChooser.select}];
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

GTKView createApplication(string[ ] args, ref const Model model) {
    import gio.Resource;
    import glib.Bytes;

    Main.init(args);
    Resource.register(new Resource(new Bytes(cast(ubyte[ ])import(`main.gresource`))));
    version (Windows) {
        import gio.Settings;

        // Windows users are unlikely to have GTK+ runtime installed, so modifying
        // their global settings once should be more or less tolerable.
        if (model.firstRun)
            new Settings("org.gtk.Settings.FileChooser").setBoolean("sort-directories-first", true);
    }
    return new GTKView;
}

private void _detectLanguage(const(char)[ ] remembered) {
    import std.algorithm.comparison: min;
    import glib.Internationalization;
    import i18n: setCurLanguage;

    if (setCurLanguage(remembered) !is null)
        return;
    foreach (code; Internationalization.getLanguageNames()) {
        if (code.length >= 5 && setCurLanguage(code[0 .. 5]) !is null)
            return;
        if (setCurLanguage(code[0 .. min(2, $)]) !is null)
            return;
    }
}

void changeUILanguage(ref string code) {
    import i18n: localize;

    _detectLanguage(code);
    code = localize!q{Meta.code};
}

int runApplication(GTKView app) {
    app.show();
    Main.run();
    return 0;
}
