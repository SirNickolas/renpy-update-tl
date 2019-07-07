module mvc.v.gtk.main_menu;

version (GTKApplication):

import gtk.MenuBar;
import gtk.MenuItem;

import i18n: Language;

@system:

final class MainMenu: MenuBar {
    private {
        MenuItem _help;
        MenuItem _about;
        MenuItem[ ] _langItems;
        void delegate(Language*) @system _onLanguageSelected;

        Language* _findLanguage(MenuItem item) nothrow @safe @nogc {
            import std.algorithm.searching: find;
            import std.range: enumerate;
            import i18n: languages;

            return &languages[_langItems.enumerate().find!q{a.value is b}(item).front.index];
        }

        void _hndOnLanguageSelected(MenuItem item) {
            if (_onLanguageSelected !is null)
                _onLanguageSelected(_findLanguage(item));
        }
    }

    this() {
        import std.algorithm.iteration;
        import std.array: array;
        import std.range: tee;

        import gtk.Menu;

        import i18n: languages, localize;

        _help = new MenuItem;
        auto sub = new Menu;
        _help.setSubmenu(sub);
        append(_help);

        _about = new MenuItem;
        sub.append(_about);

        sub = append("Language");
        _langItems =
            languages[ ]
            .map!((ref lang) => new MenuItem(&_hndOnLanguageSelected, lang.localize!q{Meta.name}))
            .cache()
            .tee!(item => sub.append(item))
            .array();
    }

    void updateStrings() {
        import i18n: localize;

        _help.setLabel(localize!q{Menu.help});
        _about.setLabel(localize!q{Menu.about});
    }

    void setOnLanguageSelected(void delegate(Language*) @system dg) {
        _onLanguageSelected = dg;
    }
}
