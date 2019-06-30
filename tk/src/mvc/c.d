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
        if (newPath.empty || !_model.trySetRenpySDKPath(newPath))
            return;
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

    private immutable(string)[ ] _getEnabledLangNames() const nothrow pure @safe {
        import std.algorithm.iteration;
        import std.array: array;
        import std.range: tee;

        return
            _model.langs
            .filter!q{a.enabled}
            .map!q{cast(immutable)a.name}
            .array();
    }

    void onBtnUpdateClick(IView view) {
        import std.algorithm.iteration;
        import mvc.m.cli_runner;

        _model.removeInvalidLangs();
        const langNames = _getEnabledLangNames();
        if (!langNames.empty) {
            const projectNumber = _model.projectNumber;
            runCLITool(_model.renpySDKPath, _model.projectPath, langNames, (CLIResult result) {
                view.executeInMainThread((IView view) {
                    view.stopAsyncWatching();
                    if (!result.output.empty) {
                        view.appendToLog(result.output);
                        if (result.output[$ - 1] != '\n')
                            view.appendToLog("\n");
                    }
                    view.appendToLog(result.ok ? "Done.\n\n" : "Failed.\n\n");
                    if (_model.projectNumber != projectNumber)
                        return;

                    _model.langs.filter!q{a.enabled}.each!q{a.ephemeral = false};
                    _model.busy = false;
                    view.update(*_model);
                });
            });
            _model.busy = true;
            view.appendToLog("Wait a few seconds, please...\n");
            view.startAsyncWatching();
        }
        view.update(*_model);
    }
}
