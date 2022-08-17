# Spine Runtime for Castle Game Engine

![image](https://user-images.githubusercontent.com/7451778/184984377-74011029-83cc-426f-ac8a-57ea5e28008f.png)

https://youtu.be/qeqasIfWLvo

https://youtu.be/kN0bVr4CJjg

Based on the official `spine-c` runtime. This provides an alternative way to load and play Spine models in Castle Game Engine (CGE) beside the engine's own runtime implementation (which lack many Spine features compare to Spine's official runtime).

## Version Requirements
Currently it provides support for Spine version 4.1. Make sure to download the correct version of dynamic library in `Release` and clone source code from the 4.1 branch.

## Additional features compare to CGE's own runtime
- Skeletal animations (can mix multiple animations on the same meshes)
- Constraints (IK, Transform, Path)
- Clipping attachments
- Point attachments
- Events

## How To Use
(by Michalis from CGE discord) To use this in your own projects, 
- Place the Pascal units in src of this repository (like CastleSpine) such that the compiler can find them. For example just clone this GitHub repo, and then edit CastleEngineManifest.xml  to add <search_paths> to point to the src here. See https://castle-engine.io/project_manifest#_compiler_options_and_paths  .
- Then you can use CastleSpine unit and TCastleSpine component from your code. TCastleSpine is a regular TCastleTransform descendant, just add it to your viewport.
- To have it available in CGE editor too, add CastleSpine unit to editor_units in your CastleEngineManifest.xml . Next time you open the project in CGE editor, it will ask you to rebuild the editor with custom components. Once the build is completed, copy dynamic library to <your_project>/castle-engine-output/editor. Once you do this, you will have an editor where you can visually add and modify TCastleSpine components, just like standard CGE TCastleScenes.

## API Reference
- TODO
