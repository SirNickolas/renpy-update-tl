module main_1;

int run() {
    import std.typecons: scoped;

    import controller;
    import model.data;
    import view.concrete;

    Model md = {
        null,
        null,
        [Lang(true, false, "english"), Lang(true, false, "chinese")],
        0,
        false,
    };
    auto app = scoped!Application();
    auto ctrl = scoped!Controller(&md);
    app.setListener(ctrl);
    app.update(md);
    app.run();
    return 0;
}
