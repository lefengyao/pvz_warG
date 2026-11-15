# FrontYard grass compatibility

本次目录整合不得破坏原有功能和代码。

- Keep `Background/Grass/Board/BoardBase` responsible for the board base.
- Keep LawnGrid/LawnCell and `lawn_cell_grass.gdshader` responsible for leaves.
- Preserve clipping, two-sided lighting, wind controls and material parameters.
- Preserve transformed model bounds, wind margins and chunk AABB calculation.
- Preserve the scene's ambient light energy of 0.6 and directional shadows.
- Run all FrontYard contracts and the lawn runtime test after relocation.
- Inspect a graphical capture of FrontYard before accepting visual compatibility.
