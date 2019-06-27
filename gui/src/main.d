import dlangui;

import std.typecons: Tuple;

private:

extern(C) __gshared string[ ] rt_options = [`gcopt=gc:precise cleanup:none`];

bool _isValidLang(const(char)[ ] name) nothrow pure @safe @nogc {
    import std.algorithm.searching: all;
    import std.ascii: isAlpha, isAlphaNum;
    import std.range: empty;
    import std.utf: byCodeUnit;

    if (name.empty || name == "None" || (!isAlpha(name[0]) && name[0] != '_'))
        return false;
    return name[1 .. $].byCodeUnit().all!(c => isAlphaNum(c) || c == '_');
}

string[ ] _collectLangs(const(char)[ ] path) {
    import std.algorithm.iteration: cache, filter, map;
    import std.algorithm.sorting: sort;
    import std.array: array;
    import std.file: SpanMode, dirEntries;
    import std.path: baseName, buildPath;
    import std.typecons: tuple;

    return
        dirEntries(buildPath(path, `game/tl`), SpanMode.shallow)
        .map!(e => tuple(baseName(e.name), e))
        .cache()
        .filter!(t => _isValidLang(t[0]) && t[1].isDir)
        .map!q{a[0]}
        .array()
        .sort()
        .release();
}

Tuple!(string, string[ ]) _collectLangs2(string path) {
    import std.file: FileException;
    import std.path: baseName, dirName;
    import std.typecons: tuple;

    try
        return tuple(path, _collectLangs(path));
    catch (FileException e) {
        if (baseName(path) != `game`)
            throw e;
        path = dirName(path);
        return tuple(path, _collectLangs(path));
    }
}

Parent _add(Parent: Widget, Children...)(Parent parent, Children children) {
    static foreach (child; children)
        parent.addChild(child);
    return parent;
}

enum _langWidth = 170;

final class _MainWidget: VerticalLayout {
private:
    import dlangui.dialogs.dialog: Dialog;

    Window _window;
    Widget _btnSelectRenpy, _edlnRenpy, _edlnProject;
    WidgetGroup _ltLangs;
    Widget _btnUpdate;
    int _existingLangs;
    uint _projectNumber;

    TableLayout _createLtLangs() {
        return new TableLayout().colCount(2);
    }

    void _replaceLtLangs(WidgetGroup ltNew) {
        auto grpbx = _ltLangs.parent;
        grpbx.removeChild(0);
        _ltLangs = ltNew;
        grpbx.addChild(ltNew);
    }

    bool _onChkbxLangClick(Widget chkbx) {
        import std.algorithm.iteration: each, map;
        import std.array: array;
        import std.range: empty, iota, retro;

        const n = _ltLangs.childIndex(chkbx);
        auto edln = _ltLangs.child(n + 1);
        if (edln.text.empty) {
            auto ltNew = _createLtLangs();
            alias move(int i) = _ => ltNew.addChild(_ltLangs.removeChild(i));
            iota(n).each!(move!0);
            iota(_ltLangs.childCount - 2).each!(move!2);
            _ltLangs.removeAllChildren(); // Without that the program crashes on exit.
            _replaceLtLangs(ltNew);
        } else if (n >> 1 >= _existingLangs)
            edln.enabled = (cast(CheckBox)chkbx).checked;
        return true;
    }

    EditLine _createEdlnLang() {
        auto edln = new EditLine;
        edln.layoutWidth = _langWidth;
        return edln;
    }

    bool _onBtnAddLangClick(Widget btn) {
        auto chkbx = new CheckBox;
        chkbx.click = &_onChkbxLangClick;
        _ltLangs
        ._add(
            chkbx
            .checked(true)
        ,
            _createEdlnLang()
        ,
            _ltLangs.removeChild(_ltLangs.childCount - 1) // The button itself.
        );
        return true;
    }

    Button _createBtnAddLang() {
        auto btn = new Button();
        btn.text = "+"d;
        btn.tooltipText = "Add a new language"d;
        btn.click = &_onBtnAddLangClick;
        return btn;
    }

    void _showDirectoryDialog(
        UIString caption,
        string path,
        void delegate(Dialog, const Action) handler,
    ) {
        import dlangui.dialogs.filedlg;

        auto dlg = new FileDialog(caption, _window, null, FileDialogFlag.SelectDirectory);
        dlg.path = path;
        dlg.dialogResult = handler;
        dlg.show();
    }

    void _onRenpySelected(Dialog dlg, const Action result) {
        import std.conv: to;
        import dlangui.dialogs.filedlg: FileDialog;

        if (result.id != ACTION_OPEN_DIRECTORY.id)
            return;
        _edlnRenpy.text = (cast(FileDialog)dlg).path.to!dstring();
    }

    void _onProjectSelected(Dialog dlg, const Action result) {
        import std.conv: to;
        import std.file: FileException;
        import dlangui.dialogs.filedlg: FileDialog;

        if (result.id != ACTION_OPEN_DIRECTORY.id)
            return;

        string path = (cast(FileDialog)dlg).path;
        string[ ] langs;
        try {
            auto t = _collectLangs2(path);
            path = t[0];
            langs = t[1];
        } catch (FileException) {
            _window.showMessageBox(
                UIString.fromRaw("Error"d),
                UIString.fromRaw(
                    `"`d ~ path.to!dstring() ~ `" doesn’t look like a Ren'Py project directory.`d,
                ),
            );
            return;
        }

        _edlnProject.text = path.to!dstring();
        _existingLangs = cast(int)langs.length;
        _projectNumber++;
        auto ltNew = _createLtLangs();
        foreach (lang; langs) {
            auto chkbx = new CheckBox;
            chkbx.click = &_onChkbxLangClick;
            ltNew
            ._add(
                new CheckBox()
                .checked(true)
            ,
                _createEdlnLang()
                .enabled(false)
                .text(lang.to!dstring())
            );
        }
        ltNew.addChild(_createBtnAddLang());
        _replaceLtLangs(ltNew);
        _btnUpdate.enabled = true;
    }

    bool _onBtnSelectClick(Widget btn) {
        import std.conv: to;

        const renpy = btn is _btnSelectRenpy;
        _showDirectoryDialog(
            UIString.fromRaw(renpy ? "Select Ren'Py SDK directory"d : "Select project directory"d),
            (renpy ? _edlnRenpy : _edlnProject).text.to!string(),
            renpy ? &_onRenpySelected : &_onProjectSelected,
        );
        return true;
    }

    public this(Window window) {
        _window = window;

        // Properties:
        margins = 8;
        layoutHeight = FILL_PARENT;

        // Children:
        _btnSelectRenpy = new ImageButton(null, "document-open");
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
                _btnSelectRenpy
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
        auto chkbxEng = new CheckBox;
        auto chkbxChn = new CheckBox;
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

        auto log = new LogWidget;
        log.vscrollbarMode = ScrollBarMode.Auto;
        log.hscrollbarMode = ScrollBarMode.Auto;
        addChild(
            log.layoutHeight(FILL_PARENT)
        );

        // Signals:
        _btnSelectRenpy.click = &_onBtnSelectClick;
        btnSelectProject.click = &_onBtnSelectClick;
        chkbxEng.click = &_onChkbxLangClick;
        chkbxChn.click = &_onChkbxLangClick;
    }
}

extern(C) int UIAppMain(string[ ] args) {
    embeddedResourceList.addResources(embedResourcesFromList!`resources.list`());
    enum height = 280;
    Window window = Platform.instance.createWindow(
        "Ren'Py translation updater"d,
        null,
        WindowFlag.Resizable,
        cast(int)(height * 1.618),
        height,
    );
    window.mainWidget = new _MainWidget(window);
    window.show();
    return Platform.instance.enterMessageLoop();
}

mixin APP_ENTRY_POINT;
