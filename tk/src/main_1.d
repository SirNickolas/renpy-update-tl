module main_1;

int run() {
    import std.typecons: scoped;
    import std.parallelism: defaultPoolThreads, totalCPUs;

    import config_file;
    import mvc.c;
    import mvc.v.concrete;

    defaultPoolThreads = totalCPUs;

    auto model = parseConfig();
    auto app = scoped!Application();
    auto ctrl = scoped!Controller(&model);
    app.setListener(ctrl);
    app.update(model);
    app.run();
    dumpConfig(model);
    return 0;
}
