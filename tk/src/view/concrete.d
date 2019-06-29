module view.concrete;

import std.typecons: Tuple, tuple;

import tkd.element.element: Element;
import tkd.tkdapplication;
import tkd.widget.widget: Widget;

import model.data: Lang, Model;
import view.iface;

private enum _declareHandler(string name) = `
    void _hnd` ~ name ~ `(CommandArgs _) nothrow {
        if (_listener !is null)
            _listener.on` ~ name ~ `(this);
    }
`;

private void _setReadOnlyValue(Entry entry, string value) {
    string[1] readOnly = [State.readonly], active = [State.active];
    entry
        .setState(active[ ])
        .setValue(value)
        .setState(readOnly[ ]);
}

final class Application: TkdApplication, IView {
private:
    Entry _entRenpySDK, _entProject;
    LabelFrame _lfrLangs;
    Widget[ ] _wLangsChildren;
    Button _btnUpdate;
    Text _txtLog;
    IViewListener _listener;

    // TODO: Write invariant.

    /+
        Event handlers.
    +/
    mixin(_declareHandler!q{BtnRenpySDKClick});
    mixin(_declareHandler!q{BtnProjectClick});
    mixin(_declareHandler!q{BtnAddLangClick});
    mixin(_declareHandler!q{BtnUpdateClick});

    void _hndLangCheckExec(Element chkbx, bool checked) nothrow {
        import std.algorithm.searching: find;
        import std.range: enumerate, stride;

        // Perform a linear search through checkboxes (even indices).
        auto tail =
            _wLangsChildren[0 .. $ - 1]
            .stride(2)
            .enumerate()
            .find!q{a.value is b}(chkbx);
        assert(!tail.empty, "Cannot find the checkbox that has just been clicked");
        _listener.onLangCheck(this, tail.front.index, checked);
    }

    void _hndLangCheck(CommandArgs args) {
        if (_listener !is null)
            _hndLangCheckExec(args.element, (cast(CheckButton)args.element).isChecked());
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
            new Button(parent, img)
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

    void _createLangsChildren(const(Lang)[ ] spec, bool busy) {
        import std.algorithm.iteration: each;

        _wLangsChildren.each!q{a.destroy()};
        _wLangsChildren.length = spec.length << 1 | 0x1;
        _wLangsChildren.assumeSafeAppend();

        string[1] readOnly = [State.readonly], disabled = [State.disabled];
        int j = 0;
        foreach (i, lang; spec) {
            // Checkbox.
            auto chkbx =
                new CheckButton(_lfrLangs)
                .setCommand(&_hndLangCheck)
                .grid(0, cast(int)i);
            if (lang.enabled)
                chkbx.check();
            if (busy)
                chkbx.setState(disabled[ ]);
            _wLangsChildren[j++] = chkbx;

            // Entry.
            auto ent =
                new Entry(_lfrLangs)
                .setValue(lang.name)
                .grid(1, cast(int)i);
            if (busy || !lang.ephemeral || !lang.enabled)
                ent.setState(readOnly[ ]);
            _wLangsChildren[j++] = ent;
        }

        // Button.
        assert(j == _wLangsChildren.length - 1);
        auto btn =
            new Button(_lfrLangs, new EmbeddedPng!`img/plus-10.png`())
            .setCommand(&_hndBtnAddLangClick)
            .grid(0, j >> 1);
        _wLangsChildren[j] = btn;
        if (busy)
            btn.setState(disabled[ ]);
    }

    void _createLangs() {
        _lfrLangs =
            new LabelFrame("Languages")
            .pack(0, 0, GeometrySide.top, GeometryFill.none, AnchorPosition.west);

        _createLangsChildren(null, false);
    }

    void _createOutput() {
        _btnUpdate =
            new Button("Update")
            .setCommand(&_hndBtnUpdateClick)
            .pack(0, 0, GeometrySide.top, GeometryFill.none, AnchorPosition.west);

        _txtLog =
            new Text()
            .setUndoSupport(false)
            .setReadOnly(true)
            .pack(0, 0, GeometrySide.top, GeometryFill.both, AnchorPosition.center, true);
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
        _createLangsChildren(model.langs, model.busy);
        string[2] states = [State.active, State.disabled];
        _btnUpdate.setState(states[model.busy .. model.busy + 1]);
    }
}
