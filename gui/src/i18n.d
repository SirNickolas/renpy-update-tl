module i18n;

import ct_ini;

nothrow @safe @nogc:

struct MsgID {
    enum MainWindow {
        title,
        renpySDKPath,
        projectPath,
        languages,
        update,
    }
    enum FileChooser {
        selectRenpySDK,
        selectProject,
        select,
    }
    enum Errors {
        error,
        invalidProject,
    }
    enum Tooltips {
        addLanguage,
    }
    enum Output {
        pleaseWait,
        done,
        failed,
    }
}

alias Language = immutable CTIni!MsgID;

Language en = parse!(MsgID, import(`l10n/en.ini`));
Language ru = parse!(MsgID, import(`l10n/ru.ini`));

private Language* _curLanguage = &ru;

@property ref Language curLanguage() {
    return *_curLanguage;
}

@property ref Language curLanguage(ref Language newLanguage) @trusted {
    _curLanguage = &newLanguage;
    return newLanguage;
}

string localize(E)(E key) if (is(E == enum)) {
    return curLanguage[key];
}

@property string localize(string key)() {
    return mixin(`localize(MsgID.` ~ key ~ `)`);
}
