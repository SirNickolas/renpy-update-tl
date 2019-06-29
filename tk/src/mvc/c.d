module mvc.c;

import std.range.primitives: empty;
import std.typecons: Yes, No;

import mvc.m.data;
import mvc.v.iface;

final class Controller: IViewListener {
    private Model* _model;

    invariant {
        assert(_model !is null);
    }

    this(Model* model) nothrow pure @safe @nogc {
        _model = model;
    }

    void onBtnRenpySDKClick(IView view) {
        const newPath = view.selectDirectory("Select Ren'Py SDK directory", _model.renpySDKPath);
        if (newPath.empty)
            return;
        _model.renpySDKPath = newPath;
        view.update(*_model);
    }

    void onBtnProjectClick(IView view) {
        const newPath = view.selectDirectory("Select project directory", _model.projectPath);
        if (newPath.empty)
            return;
        if (!_model.trySetProjectPath(newPath)) {
            view.showWarning(
                "Error",
                '"' ~ newPath ~ `" doesn’t look like a Ren'Py project directory.`,
            );
            return;
        }
        _model.incProjectNumber();
        _model.busy = false;
        view.update(*_model);
    }

    void onLangCheck(IView view, size_t index, bool checked) {
        import std.algorithm.comparison: min;

        const del = !checked && _model.langs[index].name.empty;
        if (del)
            _model.removeLang(index);
        else
            _model.langs[index].enabled = checked;
        view.update(*_model);
        if (del && !_model.langs.empty)
            view.focusLang(Yes.checkbox, min(index, _model.langs.length - 1));
    }

    void onEntLangFocusOut(IView view, size_t index, string text) nothrow pure @safe @nogc {
        _model.langs[index].name = text;
    }

    void onBtnAddLangClick(IView view) {
        _model.appendLang(Lang(true, true, null));
        view.update(*_model);
        view.focusLang(No.checkbox, _model.langs.length - 1);
    }

    void onBtnUpdateClick(IView view) { }
}
