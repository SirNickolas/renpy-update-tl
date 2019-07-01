module main_1;

int run(string[ ] args) {
    import std.typecons: scoped;
    import std.parallelism: defaultPoolThreads, totalCPUs;

    import config_file;
    import mvc.c;
    import mvc.v.tk;

    defaultPoolThreads = totalCPUs;

    auto model = parseConfig();
    scope(success) dumpConfig(model);
    auto app = createApplication(args);
    auto ctrl = scoped!Controller(&model);
    app.setListener(ctrl);
    app.update(model);
    return runApplication(app);
}
