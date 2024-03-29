module mvc.c;

import std.range.primitives: empty;
import std.typecons: Yes, No;

import i18n: Language;
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

    void onLanguageSelected(IView view, Language* language) {
        import i18n: localize, setCurLanguage;

        setCurLanguage(language);
        _model.uiLanguage = localize!q{Meta.code};
        view.updateStrings();
    }

    private void _onRenpySDKSelected(IView view, string newPath) {
        if (newPath.empty || !_model.trySetRenpySDKPath(newPath))
            return;
        view.update(*_model);
    }

    private void _onProjectSelected(IView view, string newPath) {
        import std.format: format;
        import i18n: localize;

        if (newPath.empty)
            return;
        if (!_model.trySetProjectPath(newPath)) {
            view.showWarning(
                localize!q{Errors.error},
                localize!q{Errors.invalidProject}.format(newPath),
            );
            return;
        }
        _model.incProjectNumber();
        _model.busy = false;
        view.update(*_model);
    }

    void onBtnRenpySDKClick(IView view) {
        import i18n: localize;

        view.selectDirectory(
            localize!q{FileChooser.selectRenpySDK},
            _model.renpySDKPath,
            &_onRenpySDKSelected,
        );
    }

    void onBtnProjectClick(IView view) {
        import i18n: localize;

        view.selectDirectory(
            localize!q{FileChooser.selectProject},
            _model.projectPath,
            &_onProjectSelected,
        );
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
        import std.ascii: newline;
        import i18n: MsgID, localize;
        import mvc.m.cli_runner;

        _model.removeInvalidLangs();
        const langNames = _getEnabledLangNames();
        if (!langNames.empty) {
            const projectNumber = _model.projectNumber;
            runCLITool(_model.renpySDKPath, _model.projectPath, langNames, (CLIResult result) {
                view.executeInMainThread((IView view) {
                    view.stopAsyncWatching();
                    if (!result.output.empty) {
                        static if (newline.length <= 1)
                            const output = result.output;
                        else {
                            import std.string: join, lineSplitter;

                            const output = result.output.lineSplitter().join('\n');
                        }
                        view.appendToLog(output);
                        if (output[$ - 1] != '\n')
                            view.appendToLog("\n");
                    }
                    view.appendToLog(localize(result.ok ? MsgID.Output.done : MsgID.Output.failed));

                    _model.decRunning();
                    if (_model.projectNumber == projectNumber) {
                        _model.langs.filter!q{a.enabled}.each!q{a.ephemeral = false};
                        _model.busy = false;
                    }
                    view.update(*_model);
                });
            });
            _model.incRunning();
            _model.busy = true;
            view.appendToLog(localize!q{Output.pleaseWait});
            view.startAsyncWatching();
        }
        view.update(*_model);
    }
}
