private:

extern(C) __gshared string[ ] rt_options = [`gcopt=gc:precise cleanup:none`];

version (Posix)
    int main(string[ ] args) {
        import main_1;

        return run(args);
    }
else {
    pragma(lib, "user32.lib");

    int _reportFatalError(const(wchar)* msg, const(wchar)* title) nothrow @nogc {
        import core.sys.windows.winuser;

        MessageBoxW(null, msg, title, MB_OK | MB_ICONEXCLAMATION);
        return 3;
    }

    int _reportFatalError(const(char)[ ] msg, const(wchar)* title) nothrow @nogc {
        import std.algorithm.mutation: copy;
        import std.range: take;
        import std.utf: byWchar;

        wchar[1024] buffer = void;
        msg.byWchar().take(buffer.length - 1).copy(buffer[ ])[0] = '\u0000';
        return _reportFatalError(buffer.ptr, title);
    }

    string[ ] _parseArgs() {
        import core.sys.windows.shellapi: CommandLineToArgvW;
        import core.sys.windows.winbase: GetCommandLineW, LocalFree;
        import std.algorithm.iteration: map;
        import std.array: array;
        import std.string: fromStringz;
        import std.utf: toUTF8;

        int n;
        wchar** wArgs = CommandLineToArgvW(GetCommandLineW(), &n);
        if (wArgs is null)
            throw new Exception("CommandLineToArgvW failed");
        scope(exit) LocalFree(wArgs);
        return wArgs[0 .. n].map!(p => p.fromStringz().toUTF8()).array();
    }

    extern(Windows)
    int WinMain(void* hInstance, void* hPrevInstance, char* lpCmdLine, int nCmdShow) nothrow {
        import core.runtime: Runtime;
        import std.array: array;
        import std.range: chain, only;
        import std.utf: byWchar;
        import main_1: run;

        try
            if (!Runtime.initialize())
                return _reportFatalError(
                    "`core.runtime.Runtime.initialize()` returned `false`"w.ptr,
                    "Fatal error: cannot initialize druntime",
                );
        catch (Throwable th)
            return _reportFatalError(th.msg, "Fatal error: cannot initialize druntime");

        int ret = 3;
        try
            ret = run(_parseArgs());
        catch (Throwable th) {
            string msg;
            try
                msg = th.toString(); // Attempt to get the stack trace.
            catch (Throwable th1)
                msg = th.msg; // OK, OK, having just description is fine too.
            try
                _reportFatalError(
                    chain(msg.byWchar(), only('\u0000')).array().ptr,
                    "Fatal error",
                );
            catch (Throwable th1)
                _reportFatalError(msg, "Fatal error");
        }

        try
            if (!Runtime.terminate())
                return _reportFatalError(
                    "`core.runtime.Runtime.terminate()` returned `false`"w.ptr,
                    "Fatal error: cannot terminate druntime",
                );
        catch (Throwable th)
            return _reportFatalError(th.msg, "Fatal error: cannot terminate druntime");

        return ret;
    }
}
