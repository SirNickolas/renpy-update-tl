import std.typecons: Tuple;

import po = program_options;
import tlg = tl_file.generated;
import tlu = tl_file.user;
import tlm = tl_file.merged;
import lp = tl_file.lang_pack;

private @safe:

extern(C) __gshared string[ ] rt_options = [`gcopt=gc:precise cleanup:none`];

// The compiler requires these functions to be `public`.
public auto _collectUserLangPack(Tuple!(string, const string) args) @system {
    import std.file: exists;
    import std.path: buildPath;
    import tl_file.user.file_parser;

    const path = buildPath(args.expand);
    if (exists(path))
        return lp.collect!parseFile(path, args[1]);
    return typeof(return).init;
}

public lp.LangPack!(tlm.Results) _mergeLangPacks(
    Tuple!(const lp.LangPack!(tlu.Declarations), const lp.LangPack!(tlg.Declarations)) args,
) @system {
    return lp.merge(args.expand);
}

int _run(const po.ProgramOptions options) @system {
    import std.array: appender, uninitializedArray;
    import std.conv: text;
    import std.parallelism: defaultPoolThreads, parallel, taskPool;
    import std.path: absolutePath, buildPath, dirName;
    import std.process: wait;
    import std.range: empty, repeat, zip;
    import stdf = std.file;
    import ri = renpy_interaction;

    if (options.jobs)
        defaultPoolThreads = options.jobs - 1;

    const projectPath = absolutePath(options.projectPath);
    const baseTlPath = buildPath(projectPath, `game/tl`);

    // Run Ren'Py (or don't run, depending on options).
    string renpy = `renpy`; // Search through $PATH if not specified explicitly.
    ri.GenerationResult gen;
    if (!options.debugLanguageTemplate.empty)
        gen.path = buildPath(baseTlPath, options.debugLanguageTemplate);
    else {
        if (!options.renpyPath.empty)
            renpy = ri.locateRenpyInSdk(options.renpyPath);
        gen = ri.generateTranslations(renpy, projectPath);
    }

    // Collect existing (old) translations.
    const uLangPacks = taskPool.amap!_collectUserLangPack(
        zip(repeat(baseTlPath), options.languages),
        1,
    );

    // Wait for Ren'Py to finish.
    if (options.debugLanguageTemplate.empty)
        if (const ret = gen.pid.wait())
            throw new Exception(text('`', renpy, "` terminated with code ", ret));

    // Collect the newly generated translation.
    const gLangPack = lp.collect!(tlg.parseFile)(gen.path);

    // Delete it immediately to avoid leaving garbage if something goes wrong.
    if (options.debugLanguageTemplate.empty)
        stdf.rmdirRecurse(gen.path);

    // Merge translations.
    const mLangPacks = taskPool.amap!_mergeLangPacks(
        zip(uLangPacks, repeat(gLangPack)),
        1,
    );

    // Write them back.
    const outputDir = !options.outputDir.empty ? options.outputDir : baseTlPath;
    auto wls = taskPool.workerLocalStorage(appender(uninitializedArray!(char[ ])(32 << 10)));
    foreach (z; parallel(zip(options.languages, uLangPacks, mLangPacks), 1)) {
        const lang = z[0];
        const uLangPack = z[1];
        const mLangPack = z[2];
        auto app = &wls.get();
        foreach (ref kv; mLangPack.files.byKeyValue()) {
            const uDecls = uLangPack.files.get(kv.key, tlu.Declarations.init);
            app.clear();
            tlm.emit(*app, kv.value, uDecls, gLangPack.files[kv.key], lang);
            const filename = buildPath(outputDir, lang, kv.key);
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
