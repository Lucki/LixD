module net.clienttester;

version (lixClientTester)
{
    import std.algorithm;
    import std.exception;
    import std.file;
    import std.range;
    import std.stdio;
    import core.time;
    import core.thread;

    import net.client;
    import net.structs;
    import net.style;

    void interactiveUsage()
    {
        writeln("Interactive mode. Type a command and hit [Return]:");
        writeln("q = disconnect and quit");
        writeln("c bla bla = send the chat message \"bla bla\"");
        writeln("s red = set the Lix style to red");
        writeln("l path/to/level.txt = select and transfer this level file");
        writeln("t = set feeling to thinking, i.e., not ready");
        writeln("r = set feeling to ready");
        writeln("o = set feeling to observing");
        writeln("d = describe what the network knows");
    }

    NetClient netClient;

    void calc()
    {
        foreach (_; 0 .. 10) {
            netClient.calc();
            Thread.sleep(dur!"msecs"(20));
        }
    }

    void main(string[] args)
    {
        immutable interactiveMode = args.canFind("-i");
        if (interactiveMode)
            interactiveUsage();

        NetClientCfg cfg;
        cfg.log = delegate void(string s) { s.writeln(); };
        cfg.hostname = "localhost";
        cfg.port = 22934;
        cfg.ourPlayerName = args.dropOne.filter!(arg => arg != "-i")
                                .chain(["Default"]).front;
        writeln("We are ", cfg.ourPlayerName, ".");
        netClient = new NetClient(cfg);

        if (interactiveMode) {
            calc();
            foreach (line; stdin.byLine()) {
                if (line.length < 1)
                    continue;
                else if (line[0] == 'q') {
                    netClient.disconnect();
                    break;
                }
                else if (line[0] == 'c') {
                    if (line.length <= 2 || line[1] != ' ')
                        writeln("Too few args.");
                    else
                        netClient.sendChatMessage(line[2 .. $].idup);
                }
                else if (line[0] == 's') {
                    if (line.length <= 2 || line[1] != ' ')
                        writeln("Too few args.");
                    else try
                        netClient.ourStyle = line[2 .. $].idup.stringToStyle;
                    catch (Exception) {
                        writeln("Error, `", line[2 .. $], "' is not a style.");
                        writeln("Try `red', `yellow', or `green'.");
                    }
                }
                else if (line[0] == 'l') {
                    if (line.length <= 2 || line[1] != ' ')
                        writeln("Too few args.");
                    else try
                        netClient.selectLevel(std.file.read(line[2 .. $]));
                    catch (Exception e) {
                        writeln("Error with level file `", line[2 .. $], "':");
                        writeln(e.msg);
                    }
                }
                else if (line[0] == 't')
                    netClient.ourFeeling = Profile.Feeling.thinking;
                else if (line[0] == 'r')
                    netClient.ourFeeling = Profile.Feeling.ready;
                else if (line[0] == 'o')
                    netClient.ourFeeling = Profile.Feeling.observing;
                else if (line[0] == 'd') {
                    writeln("What does the network know?");
                    writeln("    -> connected = ", netClient.connected);
                    writeln("    -> name = ", netClient.ourPlayerName);
                    writeln("    -> style = ", netClient.ourStyle);
                    netClient.describeEverything();
                }
                else
                    writeln("Unknown command: `", line[0], "'.");
                calc();
            }
        }
        else while (true) calc();
    }
}
// end version (lixClientTester)