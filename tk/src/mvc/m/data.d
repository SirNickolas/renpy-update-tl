module mvc.m.data;

struct Lang {
    bool enabled;
    bool ephemeral;
    string name;
}

struct Model {
nothrow @safe:
    string renpySDKPath;
    private {
        string _projectPath;
        Lang[ ] _langs;
        uint _projectNumber;
    }
    bool busy = true;

    @disable this(this);

    @property string projectPath() const pure @nogc {
        return _projectPath;
    }

    bool trySetProjectPath(string newPath) {
        import std.algorithm;
        import mvc.m.project_scanner;

        const result = scanProject(newPath);
        if (!result)
            return false;

        _projectPath = result.path;
        _langs.length = result.langs.length;
        () @trusted { _langs.assumeSafeAppend(); }();
        result.langs.map!(name => Lang(true, false, name)).copy(_langs[ ]);
        return true;
    }

    @property inout(Lang)[ ] langs() inout pure @nogc {
        return _langs;
    }

    void appendLang(Lang lang) pure {
        _langs ~= lang;
    }

    void removeLang(size_t index) @trusted {
        import std.algorithm.mutation;

        _langs = _langs.remove(index).assumeSafeAppend();
    }

    void removeInvalidLangs() @trusted {
        import std.algorithm.mutation;
        import mvc.m.lang;

        _langs =
            _langs
            .remove!(lang => lang.enabled && !isValidLangName(lang.name))
            .assumeSafeAppend();
    }

    @property uint projectNumber() const pure @nogc {
        return _projectNumber;
    }

    void incProjectNumber() pure @nogc {
        _projectNumber++;
    }
}
