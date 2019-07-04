module mvc.v.tk;

version (TkApplication):

import std.typecons: Flag, Yes, No, Tuple, tuple;

import tkd.element.element: Element;
import tkd.tkdapplication;
import tkd.widget.widget: Widget;

import mvc.m.data: Lang, Model;
import mvc.v.iface;

private:

enum _declareHandler(string name) = `
    void _hnd` ~ name ~ `(CommandArgs _) {
        if (_listener !is null)
            _listener.on` ~ name ~ `(this);
    }
`;

Button _newButton(Btn: Element = Button, Args...)(Args args) {
    import std.functional: forward;

    return new Btn(forward!args).bind("<Return>", (CommandArgs args) {
        (cast(Btn)args.element).invokeCommand();
    });
}

void _setReadOnlyValue(Entry entry, string value) {
    string[1] readOnly = [State.readonly];
    entry
        .removeState(readOnly[ ])
        .setValue(value)
        .setState(readOnly[ ]);
}

public final class Application: TkdApplication, IView {
private:
    Entry _entRenpySDK, _entProject;
    LabelFrame _lfrLangs;
    Widget[ ] _wLangsChildren;
    Button _btnUpdate;
    Text _txtLog;
    IViewListener _listener;
    shared size_t _asyncCount;
    shared void delegate(IView) @system[ ] _queued;

    // TODO: Write invariant.

    /+
        Event handlers.
    +/
    mixin(_declareHandler!q{BtnRenpySDKClick});
    mixin(_declareHandler!q{BtnProjectClick});
    mixin(_declareHandler!q{BtnAddLangClick});
    mixin(_declareHandler!q{BtnUpdateClick});

    size_t _getLangChildIndex(Flag!q{checkbox} checkbox, const Element e) nothrow pure @safe @nogc {
        import std.algorithm.searching: find;
        import std.range: enumerate, stride;

        // Perform a linear search through checkboxes (even indices) or entries (odd indices).
        return
            _wLangsChildren[1 - checkbox .. $ - 1]
            .stride(2)
            .enumerate()
            .find!q{a.value is b}(e)
            .front
            .index;
    }

    void _hndLangCheck(CommandArgs args) {
        if (_listener !is null)
            _listener.onLangCheck(
                this,
                _getLangChildIndex(Yes.checkbox, args.element),
                (cast(CheckButton)args.element).isChecked(),
            );
    }

    void _hndEntLangOut(CommandArgs args) {
        if (_listener !is null)
            _listener.onEntLangFocusOut(
                this,
                _getLangChildIndex(No.checkbox, args.element),
                (cast(Entry)args.element).getValue(),
            );
    }

    /+
        UI generation.
    +/
    void _configureWindow() {
        import version_;

        enum title = "Ren'Py translation updater (v" ~ programVersion ~ ')';
        enum height = 560;
        enum width = cast(int)(height * 1.618);
        mainWindow.setTitle(title);
        mainWindow.setGeometry(width, height, mainWindow.getXPos(), mainWindow.getYPos());
    }

    static Tuple!(Button, Entry) _createPathControl(Widget parent, Image img) {
        string[1] readOnly = [State.readonly];
        auto btn =
            _newButton(parent, img)
            .pack(0, 0, GeometrySide.left);
        auto ent =
            new Entry(parent)
            .setState(readOnly[ ])
            .pack(0, 0, GeometrySide.left, GeometryFill.x, AnchorPosition.center, true);
        return tuple(btn, ent);
    }

    void _createPathControls() {
        auto wrapper =
            new Frame()
            .configureGeometryColumn(1, 1)
            .pack(0, 0, GeometrySide.top, GeometryFill.x);

        new Label(wrapper, "Ren'Py SDK path:")
            .grid(0, 0, 0, 0, 1, 1, AnchorPosition.west);
        new Label(wrapper, "Project path:")
            .grid(0, 1, 0, 0, 1, 1, AnchorPosition.west);

        auto img = new EmbeddedPng!`img/document-open.png`();
        auto t = _createPathControl(new Frame(wrapper).grid(1, 0, 0, 0, 1, 1, "ew"), img);
        t[0].setCommand(&_hndBtnRenpySDKClick);
        _entRenpySDK = t[1];

        t = _createPathControl(new Frame(wrapper).grid(1, 1, 0, 0, 1, 1, "ew"), img);
        t[0].setCommand(&_hndBtnProjectClick);
        _entProject = t[1];
    }

    static void _configureLang(ref const Lang lang, bool busy, CheckButton chkbx, Entry ent) {
        string[1] readOnly = [State.readonly], disabled = [State.disabled];
        if (lang.enabled)
            chkbx.check();
        else
            chkbx.unCheck();
        if (busy)
            chkbx.setState(disabled[ ]);
        else
            chkbx.removeState(disabled[ ]);
        ent.removeState(readOnly[ ]);
        ent.setValue(lang.name);
        if (busy || !lang.enabled || !lang.ephemeral)
            ent.setState(readOnly[ ]);
    }

    void _createLangsChildren(const(Lang)[ ] spec, bool busy) {
        import std.algorithm.iteration: each;

        _wLangsChildren.each!q{a.destroy()};
        _wLangsChildren.length = spec.length << 1 | 0x1;
        _wLangsChildren.assumeSafeAppend();

        int j = 0;
        foreach (i, ref lang; spec) {
            // Checkbox.
            auto chkbx =
                new CheckButton(_lfrLangs)
                .setCommand(&_hndLangCheck)
                .grid(0, cast(int)i);
            _wLangsChildren[j++] = chkbx;

            // Entry.
            auto ent =
                new Entry(_lfrLangs)
                .bind("<FocusOut>", &_hndEntLangOut)
                .setValue(lang.name)
                .grid(1, cast(int)i);
            _wLangsChildren[j++] = ent;

            _configureLang(lang, busy, chkbx, ent);
        }

        // Button.
        assert(j == _wLangsChildren.length - 1);
        auto btn =
            _newButton(_lfrLangs, new EmbeddedPng!`img/plus-10.png`())
            .setCommand(&_hndBtnAddLangClick)
            .grid(0, j >> 1);
        _wLangsChildren[j] = btn;
        if (busy) {
            string[1] disabled = [State.disabled];
            btn.setState(disabled[ ]);
        }
    }

    void _updateLangsChildren(const(Lang)[ ] langs, bool busy) {
        foreach (i, ref lang; langs)
            _configureLang(
                lang,
                busy,
                cast(CheckButton)_wLangsChildren[i << 1],
                cast(Entry)_wLangsChildren[i << 1 | 0x1],
            );

        string[1] disabled = [State.disabled];
        if (busy)
            _wLangsChildren[$ - 1].setState(disabled[ ]);
        else
            _wLangsChildren[$ - 1].removeState(disabled[ ]);
    }

    void _createLangs() {
        _lfrLangs =
            new LabelFrame("Languages")
            .pack(0, 0, GeometrySide.top, GeometryFill.none, AnchorPosition.west);

        _createLangsChildren(null, false);
    }

    void _createOutput() {
        _btnUpdate =
            _newButton("Update")
            .setCommand(&_hndBtnUpdateClick)
            .pack(0, 0, GeometrySide.top, GeometryFill.none, AnchorPosition.west);

        auto fr =
            new Frame()
            .pack(0, 0, GeometrySide.top, GeometryFill.both, AnchorPosition.center, true);

        _txtLog =
            new Text(fr)
            .setUndoSupport(false)
            .setReadOnly(true);

        auto scroll =
            new YScrollBar(fr)
            .attachWidget(_txtLog)
            .pack(0, 0, GeometrySide.right, GeometryFill.y);

        _txtLog
            .attachYScrollBar(scroll)
            .pack(0, 0, GeometrySide.right, GeometryFill.both, AnchorPosition.center, true);
    }

    override protected void initInterface() {
        _configureWindow();
        _createPathControls();
        _createLangs();
        _createOutput();
    }

    /+
        UI updating.
    +/
    public typeof(this) setListener(IViewListener listener) nothrow pure @safe @nogc {
        _listener = listener;
        return this;
    }

    public void update(ref const Model model) {
        _setReadOnlyValue(_entRenpySDK, model.renpySDKPath);
        _setReadOnlyValue(_entProject, model.projectPath);
        if (model.langs.length == _wLangsChildren.length >> 1)
            _updateLangsChildren(model.langs, model.busy);
        else
            _createLangsChildren(model.langs, model.busy);
        string[1] disabled = [State.disabled];
        if (model.busy)
            _btnUpdate.setState(disabled[ ]);
        else
            _btnUpdate.removeState(disabled[ ]);
    }

    public void focusLang(Flag!q{checkbox} checkbox, size_t index)
    in {
        assert(index < _wLangsChildren.length >> 1);
    }
    do {
        _wLangsChildren[index << 1 | (1 - checkbox)].focus();
    }

    public void selectDirectory(
        string title,
        string initial,
        void delegate(IView, string path) @system callback,
    ) {
        import std.file: getcwd;
        import std.path: dirSeparator;
        import std.range.primitives: empty;
        import std.typecons: scoped;

        const path = {
            auto dialog = scoped!DirectoryDialog(title);
            dialog
                .setInitialDirectory(!initial.empty ? initial : getcwd())
                .setDirectoryMustExist(true)
                .show();
            return dialog.getResult();
        }();
        static if (dirSeparator != `\`)
            callback(this, path);
        else {
            import std.algorithm.iteration;
            import std.array;
            import std.utf;

            callback(this, path.byCodeUnit().substitute!('/', '\\').array());
        }
    }

    public void showWarning(string title, string text) {
        import std.typecons: scoped;

        auto dialog = scoped!MessageDialog(title);
        dialog
            .setIcon(MessageDialogIcon.warning)
            .setMessage(text)
            .show();
    }

    public void appendToLog(string text) {
        _txtLog
            .setReadOnly(false)
            .appendText(text)
            .setReadOnly(true)
            .setYView(1.);
    }

    // TODO: Factor out to a separate class.
    private void _asyncWatch(CommandArgs _) {
        synchronized (this) {
            size_t n = (cast()_queued).length;
            if (n) {
                size_t i = 0;
                do {
                    do {
                        (cast()_queued)[i](this);
                        (cast()_queued)[i++] = null;
                    } while (i < n);
                    n = (cast()_queued).length;
                } while (i < n);
                auto queued = cast()_queued;
                queued.length = 0;
                queued.assumeSafeAppend();
                cast()_queued = queued;
            }
            if (cast()_asyncCount)
                mainWindow.setIdleCommand(&_asyncWatch, 200);
        }
    }

    public void startAsyncWatching() {
        synchronized (this)
            if ((cast()_asyncCount)++)
                return;
        mainWindow.setIdleCommand(&_asyncWatch, 200);
    }

    public void executeInMainThread(void delegate(IView) @system dg) {
        synchronized (this) {
            auto queued = (cast()_queued).assumeSafeAppend();
            queued ~= dg;
            cast()_queued = queued;
        }
    }

    public void stopAsyncWatching() pure @nogc {
        size_t n;
        synchronized (this)
            n = (cast()_asyncCount)--;
        assert(n);
    }
}

public Application createApplication(string[ ] args, ref const Model model) {
    return new Application;
}

public int runApplication(Application app) {
    app.run();
    return 0;
}
