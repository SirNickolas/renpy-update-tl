module view;

import model.data: Model;

alias Handler(Args...) = void delegate(Args) nothrow @safe;

interface IView {
    @property @safe {
        IView onBtnRenpySDKClick(Handler!());
        IView onBtnProjectClick(Handler!());
        IView onLangCheck(Handler!(size_t, bool));
        IView onBtnAddLangClick(Handler!());
        IView onBtnUpdateClick(Handler!());
    }

    void update(ref const Model model);
}
