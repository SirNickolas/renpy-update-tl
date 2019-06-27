import dlangui;

import std.conv: to;
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

string _locateCliTool() @safe {
    import std.file: FileException, isFile, thisExePath;
    import std.path: buildPath, dirName;

    version (Posix)
        enum filename = `renpy-update-tl`;
    else
        enum filename = `renpy-update-tl.exe`;
    const thisDir = dirName(thisExePath());
    const s = buildPath(thisDir, filename);
    try
        if (isFile(s))
            return s;
    catch (FileException) { }
    debug {
        // Look in the parent directory as well.
        const s1 = buildPath(dirName(thisDir), filename);
        try
            if (isFile(s1))
                return s1;
        catch (FileException) { }
    }
    return filename; // Search through $PATH.
}

auto _runCliTool(
    string renpySdkPath,
    string projectPath,
    const(string)[ ] langs,
) @safe {
    import std.process: Config, execute;

    const string[4] args = [_locateCliTool(), `--renpy`, renpySdkPath, projectPath];
    return execute(args[ ] ~ langs, null, Config.suppressConsole);
}

public void _runCliTool(
    string renpySdkPath,
    string projectPath,
    immutable(string)[ ] langs,
    uint projectNumber,
    shared _MainWidget mainWidget,
) {
    try {
        const result = _runCliTool(renpySdkPath, projectPath, langs);
        auto w = cast()mainWidget;
        w.executeInUiThread({
            w.finishWork(!result.status, result.output, projectNumber);
        });
    } catch (Exception e) {
        auto w = cast()mainWidget;
        w.executeInUiThread({
            w.finishWork(false, e.msg, projectNumber);
        });
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
    LogWidget _log;
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
        import dlangui.dialogs.filedlg: FileDialog;

        if (result.id != ACTION_OPEN_DIRECTORY.id)
            return;
        _edlnRenpy.text = (cast(FileDialog)dlg).path.to!dstring();
    }

    void _onProjectSelected(Dialog dlg, const Action result) {
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
        const renpy = btn is _btnSelectRenpy;
        _showDirectoryDialog(
            UIString.fromRaw(renpy ? "Select Ren'Py SDK directory"d : "Select project directory"d),
            (renpy ? _edlnRenpy : _edlnProject).text.to!string(),
            renpy ? &_onRenpySelected : &_onProjectSelected,
        );
        return true;
    }

    bool _onBtnUpdateClick(Widget btn) {
        import std.exception: assumeUnique;
        import std.parallelism: task, taskPool;
        import std.range: iota, stride;

        if (!btn.enabled)
            return true; // DLangUI allows to click a disabled button with keyboard (?!).

        const n = _ltLangs.childCount;
        assert(n & 0b1);
        auto langs = new string[n >> 1];
        size_t langsCount = 0;
        foreach (i; iota(1, n).stride(2)) {
            if (!_ltLangs.child(i - 1).checked)
                continue;
            const lang = _ltLangs.child(i).text.to!string();
            if (!_isValidLang(lang))
                continue;
            langs[langsCount++] = lang;
        }
        if (!langsCount)
            return true;

        foreach (i; 0 .. n)
            _ltLangs.child(i).enabled = false;
        btn.enabled = false;
        _log.appendText("Wait a few seconds, please...\n"d);
        taskPool.put(task!_runCliTool(
            _edlnRenpy.text.to!string(),
            _edlnProject.text.to!string(),
            assumeUnique(langs[0 .. langsCount]),
            _projectNumber,
            cast(shared)this,
        ));
        return true;
    }

    public void finishWork(bool ok, const(char)[ ] output, uint projectNumber) {
        import std.range: empty, iota, stride;

        if (!output.empty) {
            _log.appendText(output.to!dstring());
            if (output[$ - 1] != '\n')
                _log.appendText("\n"d);
        }
        _log.appendText(ok ? "Done.\n\n"d : "Failed.\n\n"d);
        if (projectNumber != _projectNumber)
            return;

        const n = _ltLangs.childCount;
        assert(n & 0b1);
        foreach (i; iota(n).stride(2))
            _ltLangs.child(i).enabled = true; // A checkbox or the button.
        _btnUpdate.enabled = true;
        _existingLangs = n >> 1;
    }

    public this(Window window) {
        // Properties:
        _window = window;
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

        _log = new LogWidget;
        _log.vscrollbarMode = ScrollBarMode.Auto;
        _log.hscrollbarMode = ScrollBarMode.Auto;
        addChild(
            _log.layoutHeight(FILL_PARENT)
        );

        // Signals:
        _btnSelectRenpy.click = &_onBtnSelectClick;
        btnSelectProject.click = &_onBtnSelectClick;
        chkbxEng.click = &_onChkbxLangClick;
        chkbxChn.click = &_onChkbxLangClick;
        _btnUpdate.click = &_onBtnUpdateClick;
    }
}

extern(C) int UIAppMain(string[ ] args) {
    import std.parallelism: defaultPoolThreads, totalCPUs;

    defaultPoolThreads = totalCPUs;

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
