module model.data;

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
    bool busy;

    @disable this(this);

    @property string projectPath() const pure @nogc {
        return _projectPath;
    }

    bool trySetProjectPath(string newPath) {
        import std.algorithm;
        import model.project_scanner;

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

    @property uint projectNumber() const pure @nogc {
        return _projectNumber;
    }

    void incProjectNumber() pure @nogc {
        _projectNumber++;
    }
}
