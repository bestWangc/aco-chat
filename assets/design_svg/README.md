# Design SVG Assets

`source/aco_v2.svg` is the current, complete design export. Run
`node tool/split_design_svg.mjs` after replacing it with a newer `ACO.svg`.

`v2/` contains one standalone SVG per artboard, organized by feature and color
mode. `v2/index.json` maps every exported asset back to its original artboard
number and coordinates, so regenerated assets remain traceable even when the
design file has generic artboard names.

Exports are never rasterized, recompressed, scaled, or redrawn. Each file uses
the exact source artboard `viewBox`, and its vector body is copied unchanged
from the source design.

`legacy/` holds the superseded `page_XX.svg` assets and is not a source for
new implementation work.
