import dlangui;

private:

Parent _add(Parent: Widget, Children...)(Parent parent, Children children) {
    static foreach (child; children)
        parent.addChild(child);
    return parent;
}

final class _MainWidget: VerticalLayout {
    this() {
        margins = 8;
        layoutHeight = FILL_PARENT;

        addChild(
            new TableLayout()
            .colCount(3)
            .layoutWidth(FILL_PARENT)
            ._add(
                new TextWidget()
                .text("Ren'Py SDK path:"d)
            ,
                new ImageButton(null, "document-open")
                .tooltipText("Select"d)
            ,
                new EditLine()
                .layoutWidth(FILL_PARENT)
            )
            ._add(
                new TextWidget()
                .text("Project path:"d)
            ,
                new ImageButton(null, "document-open")
                .tooltipText("Select"d)
            ,
                new EditLine()
                .layoutWidth(FILL_PARENT)
            )
        );

        addChild(
            new HorizontalLayout()
            ._add(
                new GroupBox(null, "Languages"d)
                ._add(
                    new TableLayout()
                    .colCount(2)
                    ._add(
                        new CheckBox()
                        .checked(true)
                    ,
                        new EditLine()
                        .readOnly(true)
                        .layoutWidth(170)
                        .text("english"d)
                    )
                    ._add(
                        new CheckBox()
                        .checked(true)
                    ,
                        new EditLine()
                        .readOnly(true)
                        .layoutWidth(170)
                        .text("chinese"d)
                    )
                    ._add(
                        new Button()
                        .text("+"d)
                        .tooltipText("Add a new language"d)
                    )
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
    window.mainWidget = new _MainWidget;
    window.show();
    return Platform.instance.enterMessageLoop();
}

mixin APP_ENTRY_POINT;
