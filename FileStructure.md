[![3001SQ Logo](http://static.3001sq.com/red/pr/3001sq-bright.png)](https://3001sq.net "3001SQ Space Colonisation Simulator")

# **nandOS** filesystem overview

The current version of the [public 3001SQ technology demo](https://tech-demo.3001sq.net) comes with the complete [AngelScript](http://www.angelcode.com/angelscript/sdk/docs/manual/doc_script.html) source code of the **nandOS** API.

Check the [Docking Permission Granted](https://youtu.be/IO-ucXZR7nk) video to see what's already possible.

## Directories

|Path|Description|
|---|---|
|/bin|default applications controlling spaceships and stations|
|/bin/plugins|mini-programs performing single tasks like docking, device tests, trading|
|/lib|commonly used code for video bitmap mode (X17), networking (DCP), thrusters|
|/nandos/include|binary nandOS interface|
|/nandos/modules|driver code, link between user applications and devices/firmware|
|/sbin|system applications managing the boot process, starting other applications|
|/usr/bin|user programs, `hello_world` is started on bootup|
|/usr/bin/plugins|user mini-programs|
|/usr/games/bin|games that are controlled using cockpit devices|
|/usr/games/bin/plugins|mini-programs integrated in arm-display *misc* tab, starting game programs|

## Standard applications (MPS)

The programs below are started by default when booting up the **MPS spaceship**.

Their sourcecode is located in the same directory with `.as` filename extension.

|Path|Description|
|---|---|
|/bin/comms|manages communication with other vessel and provides a framework for apps|
|/bin/flightcontrol|binds sidestick axes to thruster control groups and updates navigation UI|
|/usr/bin/hello_world|default user-application that can be edited in the launcher code tab|

## Standard applications (station)

The programs below are started by default when booting up the **automated mining station**.

Their sourcecode is located in the same directory with `.as` filename extension.

|Path|Description|
|---|---|
|/bin/stationcontrol|manages station lights and communication with other spacecraft via wireless data link|

## Further resources

* [Community forums](https://forums.3001sq.net)
* [Twitter](https://twitter.com/3001sq)
* [Facebook](https://facebook.com/3001sq)
* [YouTube](https://www.youtube.com/channel/UCLK_Wq46XfR4boDl5KVJerQ)
