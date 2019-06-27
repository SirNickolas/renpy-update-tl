module application;

import tkd.tkdapplication;

final class Application: TkdApplication {
private:
    void _handleExit(CommandArgs args) {
        exit();
    }

    override protected void initInterface() {
        auto frame =
            new Frame(2, ReliefStyle.groove)
            .pack(10);

        auto label =
            new Label(frame, "Hello World!")
            .pack(10);

        auto exitButton =
            new Button(frame, "Exit")
            .setCommand(&_handleExit)
            .pack(10);
    }
}
