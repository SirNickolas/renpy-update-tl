module mvc.v.iface;

import std.typecons: Flag;

import mvc.m.data: Model;

interface IViewListener {
    void onBtnRenpySDKClick(IView);
    void onBtnProjectClick(IView);
    void onLangCheck(IView, size_t index, bool checked);
    void onEntLangFocusOut(IView, size_t index, string text);
    void onBtnAddLangClick(IView);
    void onBtnUpdateClick(IView);
}

interface IView {
    IView setListener(IViewListener) @safe;
    void updateStrings();
    void update(ref const Model model);
    void focusLang(Flag!q{checkbox} checkbox, size_t index);
    void selectDirectory(string title, string initial, void delegate(IView, string path) @system);
    void showWarning(string title, string text);
    void appendToLog(string text);
    void startAsyncWatching();
    void executeInMainThread(void delegate(IView) @system);
    void stopAsyncWatching();
}
