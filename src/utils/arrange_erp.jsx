// arrange_erp.jsx
// Adobe Illustrator ExtendScript
//
// Arranges individual ERP + topomap PDFs (from stat_erp_cbpt.m
// individual-PDF section) to match the Figure 7 layout in main.tex.
//
// Run once per condition on separate Illustrator documents:
//   Go    -> stacks go_pos_1 / go_pos_2 / go_neg_1   (3 rows)
//   No-Go -> stacks nogo_pos_1 / nogo_neg_1           (2 rows)
//
// Each row: [ERP waveform PDF] [gap] [topomap PDF]  (no row labels)
//   ERP PDF : 10 x 7 cm  (must match erp_w_cm / erp_h_cm in MATLAB)
//   Topo PDF: 4.5 x 4.5 cm (must match topo_cm in MATLAB)
//
// Usage:
//   1. Open (or create) an Illustrator document.
//   2. File > Scripts > Other Script... > select this file.
//   3. Select condition (Go / No-Go) in the dialog.
//   4. Choose the folder: result/fig_stat_erp_cbpt/individual/

#target illustrator

(function () {

    // ---- choose condition --------------------------------------------------
    var isGo = confirm(
        "Which condition?\n\n" +
        "OK     = Go    (3 rows: go_pos_1, go_pos_2, go_neg_1)\n" +
        "Cancel = No-Go (2 rows: nogo_pos_1, nogo_neg_1)"
    );

    var ROWS;
    if (isGo) {
        ROWS = ["go_pos_1", "go_pos_2", "go_neg_1"];
    } else {
        ROWS = ["nogo_pos_1", "nogo_neg_1"];
    }

    var folder = Folder.selectDialog(
        "Select the 'individual' folder  (result/fig_stat_erp_cbpt/individual)"
    );
    if (!folder) { return; }

    var doc = app.activeDocument;

    // ---- verify document colour mode is RGB ---------------------------------
    if (doc.documentColorSpace !== DocumentColorSpace.RGB) {
        var switchNow = confirm(
            "This document is in CMYK mode.\n\n" +
            "The ERP PDFs use RGB colours (DeviceRGB, no ICC profile).\n" +
            "Placing them into a CMYK document may distort colours.\n\n" +
            "Switch to RGB Color mode now?\n" +
            "(File → Document Color Mode → RGB Color)"
        );
        if (switchNow) {
            app.executeMenuCommand("doc-color-rgb");
        } else {
            alert("Aborted. Please switch to RGB Color mode manually and re-run the script.");
            return;
        }
    }

    // ---- layout parameters (centimetres -> points; 1 cm = 28.3465 pt) ------
    var PT           = 28.3465;
    var ERP_W        = 10.0 * PT;   // ERP panel width  (must match erp_w_cm in MATLAB)
    var ERP_H        =  7.0 * PT;   // ERP panel height (must match erp_h_cm in MATLAB)
    var TOPO_W       =  4.5 * PT;   // topomap width    (must match topo_cm in MATLAB)
    var TOPO_H       =  4.5 * PT;   // topomap height   (square)
    var ERP_TOPO_GAP =  0.30 * PT;  // gap between ERP panel and topomap
    var ROW_GAP      =  0.30 * PT;  // vertical gap between rows

    var N_ROWS = ROWS.length;
    var ROW_H  = ERP_H;
    var totalW = ERP_W + ERP_TOPO_GAP + TOPO_W;
    var totalH = N_ROWS * ROW_H + (N_ROWS - 1) * ROW_GAP;

    // ---- resize artboard ---------------------------------------------------
    var abRect  = doc.artboards[0].artboardRect;
    var originX = abRect[0];
    var originY = abRect[1];
    doc.artboards[0].artboardRect = [originX, originY,
                                     originX + totalW, originY - totalH];

    function rowTopY(ri) {
        return originY - ri * (ROW_H + ROW_GAP);
    }

    // ---- place ERP and topomap PDFs ----------------------------------------
    var placed  = 0;
    var missing = [];

    for (var ri = 0; ri < N_ROWS; ri++) {
        var tag    = ROWS[ri];
        var rowTop = rowTopY(ri);

        // -- ERP panel (left) --
        var erpFile = new File(folder.fullName + "/" + tag + "_erp.pdf");
        if (!erpFile.exists) {
            missing.push(tag + "_erp.pdf");
        } else {
            var erpItem  = doc.placedItems.add();
            erpItem.file = erpFile;
            var sx = (ERP_W / erpItem.width)  * 100;
            var sy = (ERP_H / erpItem.height) * 100;
            erpItem.resize(sx, sy);
            erpItem.position = [originX, rowTop];
            placed++;
        }

        // -- Topomap (right, centred vertically on the row) --
        var topoFile = new File(folder.fullName + "/" + tag + "_topo.pdf");
        if (!topoFile.exists) {
            missing.push(tag + "_topo.pdf");
        } else {
            var topoItem  = doc.placedItems.add();
            topoItem.file = topoFile;
            var tsx = (TOPO_W / topoItem.width)  * 100;
            var tsy = (TOPO_H / topoItem.height) * 100;
            topoItem.resize(tsx, tsy);
            var topoLeft = originX + ERP_W + ERP_TOPO_GAP;
            var topoTop  = rowTop - (ROW_H - TOPO_H) / 2;
            topoItem.position = [topoLeft, topoTop];
            placed++;
        }
    }

    // ---- fit artboard to all content ---------------------------------------
    var items = doc.pageItems;
    if (items.length > 0) {
        var minX =  Infinity, maxX = -Infinity;
        var maxY = -Infinity, minY =  Infinity;
        for (var i = 0; i < items.length; i++) {
            var gb = items[i].geometricBounds;
            if (gb[0] < minX) minX = gb[0];
            if (gb[1] > maxY) maxY = gb[1];
            if (gb[2] > maxX) maxX = gb[2];
            if (gb[3] < minY) minY = gb[3];
        }
        doc.artboards[0].artboardRect = [minX, maxY, maxX, minY];
    }

    // ---- report ------------------------------------------------------------
    var condName = isGo ? "Go" : "No-Go";
    var msg = condName + ": placed " + placed + " PDFs (" + N_ROWS + " rows).";
    if (missing.length > 0) {
        msg += "\n\nMissing files (" + missing.length + "):\n" + missing.join("\n");
    }
    alert(msg);

})();
