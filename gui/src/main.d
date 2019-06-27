import dlangui;

private:

extern(C) __gshared string[ ] rt_options = [`gcopt=gc:precise cleanup:none`];

Parent _add(Parent: Widget, Children...)(Parent parent, Children children) {
    static foreach (child; children)
        parent.addChild(child);
    return parent;
}

enum _langWidth = 170;

final class _MainWidget: VerticalLayout {
private:
    Window _window;
    Widget _btnSelectRenpy, _edlnRenpy, _edlnProject;
    WidgetGroup _ltLangs;
    int _existingLangs = 2;

    TableLayout _createLtLangs() {
        return new TableLayout().colCount(2);
    }

    void _replaceLtLangs(WidgetGroup ltNew) {
        auto grpbx = _ltLangs.parent;
        grpbx.removeChild(0);
        _ltLangs = ltNew;
        grpbx.addChild(ltNew);
    }

    bool _onBtnSelectClick(Widget btn) {
        import std.conv: to;
        // import std.stdio;
        import dlangui.dialogs.dialog: Dialog;
        import dlangui.dialogs.filedlg;

        auto dlg = new FileDialog(
            UIString.fromRaw("Select directory"d),
            _window,
            null,
            FileDialogFlag.SelectDirectory,
        );
        dlg.dialogResult = (Dialog _, const Action result) {
            if (result.id != ACTION_OPEN_DIRECTORY.id)
                return;
            (btn is _btnSelectRenpy ? _edlnRenpy : _edlnProject).text = dlg.path.to!dstring();
        };
        dlg.show();
        return true;
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

    bool _onBtnAddLangClick(Widget btn) {
        auto chkbx = new CheckBox;
        chkbx.click = &_onChkbxLangClick;
        _ltLangs
        ._add(
            chkbx
            .checked(true)
        ,
            new EditLine()
            .layoutWidth(_langWidth)
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
                    ._add(
                        chkbxEng
                        .checked(true)
                    ,
                        new EditLine()
                        .enabled(false)
                        .layoutWidth(_langWidth)
                        .text("english"d)
                    )
                    ._add(
                        chkbxChn
                        .checked(true)
                    ,
                        new EditLine()
                        .enabled(false)
                        .layoutWidth(_langWidth)
                        .text("chinese"d)
                    )
                    ._add(_createBtnAddLang)
                )
            )
        );

        addChild(
            new HorizontalLayout()
            ._add(
                new Button()
                .text("Update"d)
            )
        );

        auto log = new LogWidget;
        log.vscrollbarMode = ScrollBarMode.Auto;
        log.hscrollbarMode = ScrollBarMode.Auto;
        addChild(
            log
            .layoutHeight(FILL_PARENT)
            .text(
                "Wait a few seconds, please...\n1...\n2...\n3...\nA few more...\n"d ~
                "Almost done...\nJust a moment...\nDone."d
            )
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
