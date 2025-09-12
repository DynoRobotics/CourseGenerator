# Dyno Fork of Course Generator

The [Courseplay_FS25](https://github.com/Courseplay/Courseplay_FS25) contains the FarmingSimulator mod for autonomous farming vehicles. It contains both the coverage planner, ai controllers for the vehicles and GUI-stuff for the FarmingSimulator game interface.

The original [CourseGenerator](https://github.com/Courseplay/CourseGenerator) repository is a wrapper around the previously mentioned Courseplay_FS25 mod, that the developers use to develop, iterate and debug the algorithms without having to run them inside of the FarmingSimulator game. Instead, they vizualise the planned path using the Lua graphics library [Löve](https://love2d.org/).

To work with the Löve wrapper, the Courseplay_FS25 repo needs to be cloned into the root of the CourseGenerator repo, it should also be renamed to "FS25_Courseplay".

``
git clone git@github.com:Courseplay/Courseplay_FS25.git FS25_Courseplay
```

My idea now is to fork the CourseGenerator wrapper and modify it to suite our use case, hopefully it will not be necessary to make changes to Courseplay_FS25...

Turns out we do need a few minor changes to Courseplay, I've put them in a git patch, do following to apply

```bash
cd CourseGenerator/FS25_Courseplay
git apply ../courseplay.patch
```

## Tips

Enable project search of the gitignored directory FS25_Courseplay do `CTRL+,` and "Search: Use Ignore Files" and un-tick that option.

Install Lua debugger for breakpoints and inspection: tomblind.local-lua-debugger-vscode

Install Lua language server extension: sumneko.lua

Install lua interpeter: `sudo apt install lua5.2`

Install Löve:

```bash
sudo add-apt-repository ppa:bartbes/love-stable
sudo apt install love
```

Start Löve viewer: `love . fields/Goliszew.xml 13`

This should output nothing: `lua generate.lua`



# Original README from upstream repo

The Fieldwork Course Generator is a route planner for farming equipment 
like tractors or harvesters to perform their fieldwork efficiently.

The Generator is part of Courseplay, a mod for the Farming 
Simulator game but it at has no dependency on the game API and can 
run independently of the game. 

This repository contains everything you need to test the 
Course Generator in a standalone Love2D environment. 

The Course Generator code is in the Courseplay repository, this is 
only the environment, so you'll need to clone the https://github.com/Courseplay/Courseplay_FS25 to
the FS25_Courseplay folder under the root of this repo.

The `fields` folder contains field definitions exported from many Farming Simulator maps. You can load those in this standalone tool
which will show you all fields of the map. You can select any of them, set the generator parameters and run the generator to 
test how each setting work.

To run in standalone mode, start a Windows terminal, change to the root directory of the cloned repo and run 

`.\love\love.exe . fields/<field file> <field number>`

to load a field file, focus on the field identified by the number and generate a course for that field. For instance:

`.\love\love.exe . fields/Goliszew.xml 50` 

loads the fields from the Goliszew map and generates the course for field 50.
