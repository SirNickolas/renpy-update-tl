module view.iface;

import model.data: Model;

interface IViewListener {
nothrow:
    void onBtnRenpySDKClick(IView);
    void onBtnProjectClick(IView);
    void onLangCheck(IView, size_t index, bool checked);
    void onBtnAddLangClick(IView);
    void onBtnUpdateClick(IView);
}

interface IView {
    IView setListener(IViewListener) @safe;
    void update(ref const Model model);
}
