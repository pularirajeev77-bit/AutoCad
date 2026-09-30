# AutoCad

AutoLISP routines for AutoCAD.

## Commands

| File | Command | What it does |
|---|---|---|
| [PTLEAD-2.lsp](PTLEAD-2.lsp) | `PTLEAD` | Pick points and label each one's X/Y coordinates (in metres) with a multileader, on a green `corninates` layer. |
| [PL2CSV.lsp](PL2CSV.lsp) | `PL2CSV` | Export the vertex coordinates of selected polylines (LW / 2D / 3D) to a CSV file. |
| [MLE2CSV.lsp](MLE2CSV.lsp) | `MLE2CSV` | Export selected multileaders' arrow-tip coordinates and their text/block content to a CSV file. |

## How to use

1. In AutoCAD, run `APPLOAD` (or drag the `.lsp` file into the drawing).
2. Load the file you want.
3. Type the command from the table above.

### Notes
- **PTLEAD** annotates in metres using a unit factor of `0.001` (drawing units in mm). Edit `unitFactor` near the top of the file for other units (cm `0.01`, m `1.0`, ft `0.3048`, in `0.0254`). It uses the active multileader style and creates the layer `corninates` (colour 3, green) if missing.
- **PL2CSV** and **MLE2CSV** write columns with easting/northing/elevation to 4 decimals, keep trailing zeros, and offer to open the CSV when done.
