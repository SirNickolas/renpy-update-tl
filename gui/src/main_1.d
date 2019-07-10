module main_1;

int run(string[ ] args) {
    import std.typecons: scoped;
    import std.parallelism: defaultPoolThreads, totalCPUs;

    import config_file;
    import mvc.c;
    version (GTKApplication)
        import mvc.v.gtk.app;
    else
        static assert(false, "Unknown GUI backend");

    defaultPoolThreads = totalCPUs;

    auto model = parseConfig();
    scope(success) dumpConfig(model);
    auto app = createApplication(args, model);
    auto ctrl = scoped!Controller(&model);
    app.setListener(ctrl);
    changeUILanguage(model.uiLanguage);
    app.updateStrings();
    app.update(model);
    return runApplication(app);
}
