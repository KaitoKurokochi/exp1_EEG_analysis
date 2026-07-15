// arrange_topomaps.jsx
// Adobe Illustrator ExtendScript
//
// Places individual topomap PDFs (from stat_freq_cbpt_alpha section 3)
// into a 6-row x 11-column grid on the active artboard.
//
// Usage:
//   1. Open (or create) an Illustrator document.
//   2. File > Scripts > Other Script... > select this file.
//   3. Choose the folder: result/fig_freq_alpha_topo/individual/
//
// Row order (top -> bottom):  go_exp / go_nov / go_diff / nogo_exp / nogo_nov / nogo_diff
// Column order (left -> right): 0 ms, 50 ms, ..., 500 ms

#target illustrator

(function () {

    var folder = Folder.selectDialog(
        "Select the 'individual' folder  (result/fig_freq_alpha_topo/individual)"
    );
    if (!folder) { return; }

    var doc = app.activeDocument;

    // ---- grid parameters (centimetres -> points; 1 cm = 28.3465 pt) --------
    var PT      = 28.3465;
    var TOPO    = 2.96 * PT;   // topomap cell size  (matches topo_cm in MATLAB)
    var ROW_GAP = 0.50 * PT;   // vertical gap between rows (matches row_gap_cm)

    var ROW_NAMES = [
        "go_exp", "go_nov", "go_diff",
        "nogo_exp", "nogo_nov", "nogo_diff"
    ];
    var TIMES_MS = [0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

    // ---- resize artboard to fit the full grid ------------------------------
    // Total size: 11 cols x TOPO wide, 6 rows x TOPO tall + 5 gaps
    var totalW = TIMES_MS.length  * TOPO;
    var totalH = ROW_NAMES.length * TOPO + (ROW_NAMES.length - 1) * ROW_GAP;

    var abRect  = doc.artboards[0].artboardRect;  // [left, top, right, bottom]
    var originX = abRect[0];
    var originY = abRect[1];   // top edge (y increases upward in Illustrator)

    // Keep top-left corner fixed; extend right and down to fit all cells
    doc.artboards[0].artboardRect = [originX, originY, originX + totalW, originY - totalH];

    var placed_count = 0;
    var missing      = [];

    for (var ri = 0; ri < ROW_NAMES.length; ri++) {
        for (var ti = 0; ti < TIMES_MS.length; ti++) {

            var t_ms  = TIMES_MS[ti];
            var pad   = ("000" + t_ms).slice(-3);
            var fname = ROW_NAMES[ri] + "_" + pad + "ms.pdf";
            var file  = new File(folder.fullName + "/" + fname);

            if (!file.exists) {
                missing.push(fname);
                continue;
            }

            // Top-left corner of this cell in Illustrator coordinates
            var x = originX + ti * TOPO;
            var y = originY - ri * (TOPO + ROW_GAP);

            var item  = doc.placedItems.add();
            item.file = file;
            // Calculate exact scale from the PDF's natural page size to TOPO
            var scaleX = (TOPO / item.width)  * 100;
            var scaleY = (TOPO / item.height) * 100;
            item.resize(scaleX, scaleY);   // resize before setting position
            item.position = [x, y];        // [left edge, top edge]
            // Note: embed() is intentionally omitted.
            // Colours are preserved correctly when the document is in RGB mode
            // (File > Document Color Mode > RGB Color) and colour management
            // policies are set to Off (Edit > Color Settings > RGB: Off).

            placed_count++;
        }
    }

    // ---- report result -----------------------------------------------------
    var msg = "Placed " + placed_count + " topomap PDFs.";
    if (missing.length > 0) {
        msg += "\n\nMissing files (" + missing.length + "):\n";
        msg += missing.slice(0, 8).join("\n");
        if (missing.length > 8) { msg += "\n..."; }
    }
    alert(msg);

})();
