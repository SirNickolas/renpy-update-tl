module i18n;

import ct_ini;

nothrow @safe:

struct MsgID {
    enum Meta {
        code,
        name,
    }
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

Language[2] languages = [
    parse!(MsgID, import(`l10n/en_US.ini`)),
    parse!(MsgID, import(`l10n/ru_RU.ini`)),
];

private Language* _curLanguage = &languages[0];
immutable Language*[string] languageRegistry;

shared static this() @trusted {
    version (assert)
        bool[string] used;
    foreach (ref lang; languages[ ]) {
        immutable code = lang[MsgID.Meta.code];
        version (assert) {
            assert(code !in used, "Duplicate language code: " ~ code);
            used[code] = true;
        }
        languageRegistry[code] = &lang;
        if (code.length > 2 && code[0 .. 2] !in languageRegistry)
            languageRegistry[code[0 .. 2]] = &lang;
    }
}

@property ref Language curLanguage() @nogc {
    return *_curLanguage;
}

Language* setCurLanguage(const(char)[ ] code) @nogc {
    if (immutable p = code in languageRegistry) {
        _curLanguage = *p;
        return *p;
    }
    return null;
}

string localize(E)(E key) @nogc if (is(E == enum)) {
    return curLanguage[key];
}

@property string localize(string key)() @nogc {
    return mixin(`localize(MsgID.` ~ key ~ `)`);
}
