module application;

import std.typecons: Tuple, tuple;

import tkd.tkdapplication;
import tkd.widget.widget: Widget;

final class Application: TkdApplication {
private:
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

    static void _createPathControls() {
        auto wrapper =
            new Frame()
            .configureGeometryColumn(1, 1)
            .pack(0, 0, GeometrySide.top, GeometryFill.x);

        new Label(wrapper, "Ren'Py SDK path:")
            .grid(0, 0, 0, 0, 1, 1, AnchorPosition.west);
        new Label(wrapper, "Project path:")
            .grid(0, 1, 0, 0, 1, 1, AnchorPosition.west);

        auto img = new EmbeddedPng!`img/document-open.png`();
        _createPathControl(new Frame(wrapper).grid(1, 0, 0, 0, 1, 1, "ew"), img);
        _createPathControl(new Frame(wrapper).grid(1, 1, 0, 0, 1, 1, "ew"), img);
    }

    static void _createLangs() {
        auto lfr =
            new LabelFrame("Languages")
            .pack(0, 0, GeometrySide.top, GeometryFill.none, AnchorPosition.west);

        string[1] readOnly = [State.readonly];
        new CheckButton(lfr)
            .check()
            .grid(0, 0);
        new Entry(lfr)
            .setValue("english")
            .setState(readOnly[ ])
            .grid(1, 0);
        new CheckButton(lfr)
            .check()
            .grid(0, 1);
        new Entry(lfr)
            .setValue("chinese")
            .setState(readOnly[ ])
            .grid(1, 1);
        new Button(lfr, new EmbeddedPng!`img/plus-10.png`())
            .grid(0, 2);
    }

    static void _createOutput() {
        new Button("Update")
            .pack(0, 0, GeometrySide.top, GeometryFill.none, AnchorPosition.west);

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
}

int run() {
    import std.typecons;

    auto app = scoped!Application();
    app.run();
    return 0;
}
