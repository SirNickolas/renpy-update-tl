module mvc.m.data;

struct Lang {
    bool enabled;
    bool ephemeral;
    string name;
}

struct Model {
nothrow @safe:
    private {
        string _renpySDKPath;
        string _projectPath;
        Lang[ ] _langs;
        uint _projectNumber;
        uint _running;
    }
    bool busy = true;

    invariant {
        assert(_langs.length <= int.max); // Necessary for GUI frameworks to work correctly.
        // Anyway, the program will run out of memory long before this limit is reached.
    }

    @disable this(this);

    @property string renpySDKPath() const pure @nogc {
        return _renpySDKPath;
    }

    bool trySetRenpySDKPath(string newPath) {
        import std.path: isValidPath;

        if (!isValidPath(newPath))
            return false;
        _renpySDKPath = newPath;
        return true;
    }

    @property string projectPath() const pure @nogc {
        return _projectPath;
    }

    bool trySetProjectPath(string newPath) {
        import std.algorithm;
        import std.path: isValidPath;
        import mvc.m.project_scanner;

        if (!isValidPath(newPath))
            return false;
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

    @property uint running() const pure @nogc {
        return _running;
    }

    void incRunning() pure @nogc {
        _running++;
    }

    void decRunning() pure @nogc
    in {
        assert(_running);
    }
    do {
        _running--;
    }
}
