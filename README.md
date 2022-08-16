# Spine Runtime for Castle Game Engine
Based on the official `spine-c` runtime. This provides an alternative way to load and play Spine models in Castle Game Engine (CGE) beside the engine's own runtime implementation (which lack many Spine features compare to Spine's official runtime).

## Version Requirements
Currently it provides support for Spine version 4.0 and 4.1. Make sure to download the correct version of binaries in `Release` and clone source code from the correct branch (4.0, 4.1).

## How To Use
(by Michalis from CGE discord) To use this in your own projects, 
- Place the Pascal units in src of this repository (like CastleSpine) such that the compiler can find them. For example just clone this GitHub repo, and then edit CastleEngineManifest.xml  to add <search_paths> to point to the src here. See https://castle-engine.io/project_manifest#_compiler_options_and_paths  .
- Then you can use CastleSpine unit and TCastleSpine component from your code. TCastleSpine is a regular TCastleTransform descendant, just add it to your viewport.
- To have it available in CGE editor too, add CastleSpine unit to editor_units in your CastleEngineManifest.xml . Next time you open the project in CGE editor, it will ask you to rebuild the editor with custom components. Once you do this, you will have an editor where you can visually add and modify TCastleSpine components, just like standard CGE TCastleScenes.

## API Reference
- TODO
