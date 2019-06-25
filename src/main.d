import std.typecons: Tuple;

import po = program_options;
import tlg = tl_file.generated;
import tlu = tl_file.user;
import tlm = tl_file.merged;
import lp = tl_file.lang_pack;

private @safe:

extern(C) __gshared string[ ] rt_options = ["gcopt=gc:precise cleanup:none"];

// The compiler requires these functions to be `public`.
public auto _collectUserLangPack(Tuple!(string, const string) args) @system {
    import std.path: buildPath;
    import tl_file.user.file_parser;

    return lp.collect!parseFile(buildPath(args.expand), args[1]);
}

public lp.LangPack!(tlm.Results) _mergeLangPacks(
    Tuple!(const lp.LangPack!(tlu.Declarations), const lp.LangPack!(tlg.Declarations)) args,
) nothrow {
    return lp.merge(args.expand);
}

int _run(const po.ProgramOptions options) @system {
    import std.array: appender, array, uninitializedArray;
    import std.parallelism: defaultPoolThreads, parallel, taskPool;
    import std.path: asAbsolutePath, buildPath, chainPath, dirName;
    import std.range: empty, repeat, zip;
    import std.stdio;
    import stdf = std.file;

    if (options.debugLanguageTemplate.empty)
        assert(false, "Running without `--assume-fresh` is not implemented yet");
    if (options.outputDir.empty)
        assert(false, "Running without `-o` is not implemented yet");

    if (options.jobs)
        defaultPoolThreads = options.jobs - 1;

    immutable baseTlPath = chainPath(options.projectPath, "game/tl").asAbsolutePath().array();

    string gPath;
    if (options.debugLanguageTemplate.empty) {
        // TODO: Run Ren'Py.
        assert(false);
    } else
        gPath = buildPath(baseTlPath, options.debugLanguageTemplate);

    const uLangPacks = taskPool.amap!_collectUserLangPack(
        zip(repeat(baseTlPath), options.languages),
        1,
    );

    if (options.debugLanguageTemplate.empty) {
        // TODO: Wait for Ren'Py to finish.
        assert(false);
    }

    const gLangPack = lp.collect!(tlg.parseFile)(gPath);

    const mLangPacks = taskPool.amap!_mergeLangPacks(
        zip(uLangPacks, repeat(gLangPack)),
        1,
    );

    const targetPath = options.outputDir; // TODO.
    auto wls = taskPool.workerLocalStorage(appender(uninitializedArray!(char[ ])(32 << 10)));
    foreach (z; parallel(zip(options.languages, uLangPacks, mLangPacks), 1)) {
        const lang = z[0];
        const uLangPack = z[1];
        const mLangPack = z[2];
        auto app = &wls.get();
        foreach (ref kv; mLangPack.files.byKeyValue()) {
            app.clear();
            tlm.emit(*app, kv.value, uLangPack.files[kv.key], gLangPack.files[kv.key], lang);
            const filename = buildPath(targetPath, lang, kv.key);
            stdf.mkdirRecurse(dirName(filename));
            stdf.write(filename, app.data);
        }
    }

    return 0;
}

int main(string[ ] args) @system {
    import sumtype;

    return po.parse(args).match!(
        (po.HelpRequested _) => 0,
        (po.ParseError _) => 2,
        o => _run(o),
    );
}
