module main_1;

int run() {
    import std.typecons: scoped;
    import std.parallelism: defaultPoolThreads, totalCPUs;

    import mvc.c;
    import mvc.m.data;
    import mvc.v.concrete;

    defaultPoolThreads = totalCPUs;

    Model model;
    auto app = scoped!Application();
    auto ctrl = scoped!Controller(&model);
    app.setListener(ctrl);
    // app.update(model);
    app.run();
    return 0;
}
