# Town models: how to make them and drop them in

The town view (TOWN_GRID) draws each town in 3D. Every kind of building is a slot. If a slot's folder has models, the
view uses them. If not, it draws a plain low-poly block of the right size. You can add models one slot at a time;
the rest keeps its blocks.

## Where the files go

`game/assets/town/<SLOT>/` holds `.glb` files (best: one file with its materials inside) or `.gltf`. Any file name
works, for example `game/assets/town/HOUSE/cottage_a.glb` and `game/assets/town/HOUSE/cottage_b.glb`.

The slots are: HOUSE, APARTMENT, TOWER, SHOP, BAKERY, CLINIC, SCHOOL, CARE, OFFICE, POLICE, WORKS, DEPOT, MINE,
FARM, TREE.

## Units, origin and front

- **Units:** 1 unit = 1 metre. Export from SketchUp in metres.
- **Cell size:** a town cell is 100 m × 100 m.
- **Origin:** in the middle of the building's footprint, on the ground. The ground is height 0, so nothing should
  hang below it, and no base plate is needed.
- **Front:** the door side, which faces the street. Model the front facing you in SketchUp's Front view (towards
  minus the green axis). Blender's Front view works the same way. The exporters turn this into glTF's front (+Z),
  which is what the game expects.
- **Up** is SketchUp's blue axis. The exporter handles the conversion.

## How big each slot may be

Footprint is width × depth, in metres. The block the game draws now is this size; a model may be smaller.

| Slot | Footprint at most | Height at most | How it is placed |
|---|---|---|---|
| HOUSE | 14 × 14 | 10 | up to 10 to a cell, in two rows of 5 on 20 m lots, fronts to the streets north and south |
| APARTMENT | 48 × 16 | 15 (4–5 storeys) | 1–2 slabs to a cell, fronts to the streets |
| TOWER | 24 × 24 | 50 (about 15 storeys) | 1–2 to a cell |
| SHOP | 26 × 18 | 6 | one to a cell, front south |
| BAKERY | 14 × 12 | 7 | one to a cell |
| CLINIC | 40 × 26 | 9 | one to a cell |
| SCHOOL | 56 × 34 | 9 | one to a cell |
| CARE (child or elder care) | 30 × 20 | 7 | one to a cell |
| OFFICE (offices, services, the job centre) | 30 × 20 | 15 | one to a cell |
| POLICE | 26 × 18 | 8 | one to a cell |
| WORKS (plants, power, water works) | 70 × 50 | 16 | in the country, at its site |
| DEPOT (depots, warehouses, transit) | 70 × 44 | 10 | in the country |
| MINE | 40 × 40 | 22 (headframe) | in the country |
| FARM (the farmhouse; the fields are drawn) | 16 × 12 | 8 | in the country, beside its fields |
| TREE | 8 × 8 | 11 | scattered on open land |

## Variety

- **Several models in a folder:** each building picks one from its cell and lot, so a street mixes them. The pick is
  the same every time you look.
- **Small changes the game adds:** each building is also turned up to 4° either way, and its colours are made up to 8%
  lighter or darker.
- **How many:** three variants of a slot are enough to stop a street looking repeated. Two are fine for the rarer
  slots.

**What to make first** (in order of what shows most on screen):
1. HOUSE: 3–5 variants. Houses are almost every building in a young town.
2. TREE: 2–3 variants.
3. APARTMENT: 2–3.
4. SHOP, SCHOOL, CLINIC: 1–2 each.
5. OFFICE, BAKERY, CARE, POLICE: 1 each.
6. WORKS, DEPOT, MINE, FARM: 1 each.
7. TOWER: 1–2. None appear until a town has apartments.

## Low-poly budget

Keep a house to about 2,000 triangles or fewer, because a town has hundreds of them. An apartment block or a public
building can take 3,000–5,000, and a tower about 5,000.

- **Colours:** plain colours or small textures work best.
- **Leave out:** lights and cameras. If the file holds them, the game ignores them.
- **Painting:** your painting program is fine as long as it writes glTF with the materials inside (.glb).

## How to see them

1. Put the files in the slot's folder.
2. In the game, select a settlement on the colony map and press **Town view**. The view looks in the folders every
   time it opens, so new files show at once. Opening the project in the Godot editor once also imports them, which
   makes later loading faster.
3. Or take a picture without playing:
   `godot --path game --script res://tools/shot_town.gd -- 1 town.png 6 d:1`
   This saves `town.png` (the whole town) and `town_close.png` (a low view along the streets).
   - The arguments are: the seed, the output file, months to run, and the town (d:1 to d:6).
   - An optional last argument such as `APARTMENT,HOUSE` allows apartments, so you can see that slot.

**If a model looks wrong:**
- Very large or very small: it was exported in other units (inches or centimetres). Export in metres.
- Facing away from the street: turn it 180° so its front faces you in SketchUp's Front view.
- Floating or sunk: move it so its base sits at height 0.
