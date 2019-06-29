module main_1;

int run() {
    import std.typecons: scoped;

    import application;
    import model.data;

    auto app = scoped!Application();
    Model md = {
        null,
        null,
        [Lang(true, false, "english"), Lang(true, false, "chinese")],
        0,
        false,
    };
    app.update(md);
    app.run();
    return 0;
}
