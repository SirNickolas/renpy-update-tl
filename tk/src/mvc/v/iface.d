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
    void update(ref const Model model);
    void focusLang(Flag!q{checkbox} checkbox, size_t index);
    string selectDirectory(string title, string initial);
    void showWarning(string title, string text);
    void appendToLog(string text);
    void startAsyncWatching();
    void executeInMainThread(void delegate(IView) @system);
    void stopAsyncWatching();
}
