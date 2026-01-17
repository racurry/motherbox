# OpenSCAD

3D modeling via code.

## Setup

```bash
./apps/openscad/openscad.sh
```

## Usage

**VS Code:**

1. Open `.scad` file
2. Click "Preview in OpenSCAD" (top right)
3. Edit & save - preview auto-reloads

**Command-line:**

```bash
openscad -o output.stl input.scad
openscad -o output.stl -D 'param=value' input.scad
```

## Libraries

Libraries are stored in `~/OpenSCAD/Libraries` (set via `$OPENSCADPATH` in zshrc).

**Included libraries:**

- [BOSL2](https://github.com/BelfrySCAD/BOSL2) - Belfry OpenSCAD Library v2 (auto-installed by setup)

To update BOSL2: `git -C ~/OpenSCAD/Libraries/BOSL2 pull`

## Resources

- [Cheatsheet](https://openscad.org/cheatsheet/)
- [Tutorial](https://openscad.org/documentation.html)
- Example: `example.scad`
