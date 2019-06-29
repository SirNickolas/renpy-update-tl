module controller;

import model.data;
import view.iface;

final class Controller: IViewListener {
nothrow:
    private Model* _model;

    invariant {
        assert(_model !is null);
    }

    this(Model* model) pure @safe @nogc {
        _model = model;
    }

    void onBtnRenpySDKClick(IView view) { }

    void onBtnProjectClick(IView view) { }

    void onLangCheck(IView view, size_t index, bool checked) @safe { }

    void onBtnAddLangClick(IView view) @safe { }

    void onBtnUpdateClick(IView view) @safe { }
}
