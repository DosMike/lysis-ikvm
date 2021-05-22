Lysis-IKVM
=====

This project will build lysis-java as .net library.
Since the license for lysis-java is not clear it currently builds from scratch.

For this project to build, you need Visual Studio with .Net and Windows SDK as
well as a java 8 JDK and git bash for windows (not WSL, that wouldn't work for me for some reason).

I don't exactly know what Visual Studio package is hiding the Resource Compiler rc.exe, but you need it!
Usually it's somewhere in `C:\Windows Kits\`

If everything is installed it should be as easy as running `getlysis.bat` through cmd.

Process
-----

Before Running you need to

- Install Visual Studio for C# and Windows Platform Tools (I believe Windows Kits is in here?)
- Install Java 8 JDK
- Install git (for example git-bash for windows from git-scm)
- Have a somewhat recent Windows (curl should be in path)
- Find your Windows Kits directory and
- Patch it in the script (one of the first lines)

The script currently works like this:

- Download ikvm8 from windward-studios
- Download NAnt-0.92
- Patch ICSharpCode.SharpZipLib into ikvms bin/ dir
- NAnt build ikvm8
- Clone the library fork DosMike/lysis-java
- Build lysis with Gradlew jar 
- Convert the artifact into a dll using ikvm

It's currently not super stable and might require you to run the script twice...

Using the dll
-----

I also noticed that the `IKVM.WINDWARD` NuGet does not work for some reason
so I had to copy the `IKVM.OpenJDK.Core.dll` as well as `lysis-java.dll`.

Depend on both and resolve new ambiguities in your Code. For example `Exception` could
now point to `System.Exception` or `java.lang.Exception`
