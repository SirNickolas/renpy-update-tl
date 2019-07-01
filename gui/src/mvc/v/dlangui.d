module mvc.v.dlangui;

version (none):

import std.conv: to;
import std.typecons: Flag, Yes, No;

import dlangui;

import mvc.m.data: Lang, Model;
import mvc.v.iface;

private @system:

enum _declareHandler(string name) = `
    bool _hnd` ~ name ~ `(Widget widget) {
        // DLangUI allows to click a disabled button with keyboard (?!).
        if (_listener !is null && widget.enabled)
            _listener.on` ~ name ~ `(this);
        return true;
    }
`;

enum _langWidth = 170;

Parent _add(Parent: Widget, Children...)(Parent parent, Children children) {
    static foreach (child; children)
        parent.addChild(child);
    return parent;
}

public final class MainWidget: VerticalLayout, IView {
private:
    Window _window;
    Widget _edlnRenpy, _edlnProject;
    WidgetGroup _ltLangs;
    Widget _btnUpdate;
    LogWidget _log;
    IViewListener _listener;

    /+
        Event handlers.
    +/
    mixin(_declareHandler!q{BtnRenpySDKClick});
    mixin(_declareHandler!q{BtnProjectClick});
    mixin(_declareHandler!q{BtnAddLangClick});
    mixin(_declareHandler!q{BtnUpdateClick});

    bool _hndLangCheck(Widget widget) {
        const index = _ltLangs.childIndex(widget);
        assert(index != -1);
        _listener.onLangCheck(this, index, (cast(CheckBox)widget).checked);
        return true;
    }

    bool _hndLangFocus(Widget widget, bool focused) {
        if (focused)
            return true;
        const index = _ltLangs.childIndex(widget);
        assert(index != -1);
        _listener.onEntLangFocusOut(this, index, widget.text.to!string());
        return true;
    }

    /+
        UI generation.
    +/
    TableLayout _createLtLangs() {
        return new TableLayout().colCount(2);
    }

    EditLine _createEdlnLang() {
        auto edln = new EditLine;
        edln.layoutWidth = _langWidth;
        return edln;
    }

    Button _createBtnAddLang() {
        auto btn = new Button();
        btn.text = "+"d;
        btn.tooltipText = "Add a new language"d;
        btn.click = &_hndBtnAddLangClick;
        return btn;
    }

    void _configureLang(ref const Lang lang, bool busy, CheckBox chkbx, EditLine edln) {
        chkbx.checked = lang.enabled;
        chkbx.enabled = !busy;
        edln.text = lang.name.to!dstring();
        edln.enabled = !(busy || !lang.enabled || !lang.ephemeral);
    }

    void _replaceLtLangs(WidgetGroup ltNew)
    in {
        assert(ltNew !is _ltLangs);
    }
    do {
        auto grpbx = _ltLangs.parent;
        _ltLangs.removeAllChildren();
        grpbx.removeAllChildren();
        grpbx.addChild(ltNew);
        _ltLangs = ltNew;
    }

    void _createLangsChildren(const(Lang)[ ] langs, bool busy) {
        auto ltNew = _createLtLangs();
        foreach (ref lang; langs) {
            auto chkbx = new CheckBox;
            auto edln = _createEdlnLang();
            chkbx.click = &_hndLangCheck;
            edln.focusChange = &_hndLangFocus;
            _configureLang(lang, busy, chkbx, edln);
            ltNew._add(chkbx, edln);
        }
        ltNew.addChild(_createBtnAddLang().enabled(!busy));
        _replaceLtLangs(ltNew);
    }

    void _updateLangsChildren(const(Lang)[ ] langs, bool busy) {
        foreach (i, ref lang; langs)
            _configureLang(
                lang,
                busy,
                cast(CheckBox)_ltLangs.child(cast(int)i << 1),
                cast(EditLine)_ltLangs.child(cast(int)i << 1 | 0x1),
            );
        _ltLangs.child(cast(int)langs.length << 1).enabled = !busy;
    }

    public this(Window window) {
        // Properties:
        _window = window;
        margins = 8;
        layoutHeight = FILL_PARENT;

        // Children:
        auto btnSelectRenpy = new ImageButton(null, "document-open");
        auto btnSelectProject = new ImageButton(null, "document-open");
        _edlnRenpy = new EditLine;
        _edlnProject = new EditLine;

        addChild(
            new TableLayout()
            .colCount(3)
            .layoutWidth(FILL_PARENT)
            ._add(
                new TextWidget()
                .text("Ren'Py SDK path:"d)
            ,
                btnSelectRenpy
                .tooltipText("Select"d)
            ,
                _edlnRenpy
                .enabled(false)
                .layoutWidth(FILL_PARENT)
            )
            ._add(
                new TextWidget()
                .text("Project path:"d)
            ,
                btnSelectProject
                .tooltipText("Select"d)
            ,
                _edlnProject
                .enabled(false)
                .layoutWidth(FILL_PARENT)
            )
        );

        auto ltLangs = _createLtLangs();
        _ltLangs = ltLangs;
        addChild(
            new HorizontalLayout()
            ._add(
                new GroupBox(null, "Languages"d)
                ._add(
                    ltLangs
                    ._add(_createBtnAddLang().enabled(false))
                )
            )
        );

        _btnUpdate = new Button;
        addChild(
            new HorizontalLayout()
            ._add(_btnUpdate.enabled(false).text("Update"d))
        );

        _log = new LogWidget;
        _log.vscrollbarMode = ScrollBarMode.Auto;
        _log.hscrollbarMode = ScrollBarMode.Auto;
        addChild(
            _log.layoutHeight(FILL_PARENT)
        );

        // Signals:
        btnSelectRenpy.click = &_hndBtnRenpySDKClick;
        btnSelectProject.click = &_hndBtnProjectClick;
        _btnUpdate.click = &_hndBtnUpdateClick;
    }

    /+
        UI updating.
    +/
    public typeof(this) setListener(IViewListener listener) nothrow pure @safe @nogc {
        _listener = listener;
        return this;
    }

    public void update(ref const Model model) {
        _edlnRenpy.text = model.renpySDKPath.to!dstring();
        _edlnProject.text = model.projectPath.to!dstring();
        if (model.langs.length == _ltLangs.childCount >> 1)
            _updateLangsChildren(model.langs, model.busy);
        else
            _createLangsChildren(model.langs, model.busy);
        _btnUpdate.enabled = !model.busy;
    }

    public void focusLang(Flag!q{checkbox} checkbox, size_t index)
    in {
        assert(index < _ltLangs.childCount >> 1);
    }
    do {
        _ltLangs.child(cast(int)index << 1 | (1 - checkbox)).setFocus();
    }

    public void selectDirectory(
        string title,
        string initial,
        void delegate(IView, string path) @system callback,
    ) {
        import dlangui.dialogs.dialog: Dialog;
        import dlangui.dialogs.filedlg: FileDialog, FileDialogFlag;

        auto dlg = new FileDialog(
            UIString.fromRaw(title),
            _window,
            null,
            FileDialogFlag.SelectDirectory,
        );
        dlg.path = initial;
        dlg.dialogResult = (Dialog dlg, const Action result) {
            callback(
                this,
                result.id == ACTION_OPEN_DIRECTORY.id ? (cast(FileDialog)dlg).path : null,
            );
        };
        dlg.show();
    }

    public void showWarning(string title, string text) {
        _window.showMessageBox(
            UIString.fromRaw(title.to!dstring()),
            UIString.fromRaw(text.to!dstring()),
        );
    }

    public void appendToLog(string text) {
        _log.appendText(text.to!dstring());
    }

    // Not needed for this backend.
    public void startAsyncWatching() const nothrow pure @safe @nogc { }
    public void stopAsyncWatching() const nothrow pure @safe @nogc { }

    public void executeInMainThread(void delegate(IView) @system dg) {
        executeInUiThread({ dg(this); });
    }
}

public MainWidget createApplication() {
    import version_: programVersion;

    embeddedResourceList.addResources(embedResourcesFromList!`resources.list`());
    enum title = "Ren'Py translation updater (v"d ~ programVersion.to!dstring() ~ ")"d;
    enum height = 280;
    Window window = Platform.instance.createWindow(
        title,
        null,
        WindowFlag.Resizable,
        cast(int)(height * 1.618),
        height,
    );
    auto widget = new MainWidget(window);
    window.mainWidget = widget;
    return widget;
}

public int runApplication(MainWidget widget) {
    widget._window.show();
    return Platform.instance.enterMessageLoop();
}
