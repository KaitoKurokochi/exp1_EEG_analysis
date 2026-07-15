// arrange_erp.jsx
// Adobe Illustrator ExtendScript
//
// Places individual ERP panel and topomap PDFs (from stat_erp_cbpt.m
// individual-PDF section) into a 5-row grid on the active artboard.
//
// Usage:
//   1. Open (or create) an Illustrator document.
//   2. File > Scripts > Other Script... > select this file.
//   3. Choose the folder: result/fig_stat_erp_cbpt/individual/
//
// Row order (top -> bottom):
//   (a) go_pos_1  — Go,    positive cluster 1  (frontocentral,  51-109 ms)
//   (b) go_pos_2  — Go,    positive cluster 2  (parieto-occ,   113-164 ms)
//   (c) go_neg_1  — Go,    negative cluster 1  (centroparietocc,176-258 ms)
//   (d) nogo_pos_1 — No-Go, positive cluster 1 (frontocentral,  47-141 ms)
//   (e) nogo_neg_1 — No-Go, negative cluster 1 (centroparietocc,184-254 ms)
//
// Each row: [label] [ERP waveform panel] [gap] [topomap]

#target illustrator

(function () {

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
    var PT        = 28.3465;
    var ERP_W     = 9.0 * PT;   // ERP panel width  (must match erp_w_cm in MATLAB)
    var ERP_H     = 6.0 * PT;   // ERP panel height (must match erp_h_cm in MATLAB)
    var TOPO_W    = 4.5 * PT;   // topomap width    (must match topo_cm in MATLAB)
    var TOPO_H    = 4.5 * PT;   // topomap height   (square)
    var ERP_TOPO_GAP = 0.30 * PT;   // gap between ERP panel and topomap
    var ROW_GAP      = 0.50 * PT;   // vertical gap between rows
    var LABEL_W      = 1.00 * PT;   // space for row labels on the left
    var LABEL_FONT   = 26;          // pt

    // ---- row definitions ---------------------------------------------------
    // file tag (without _erp.pdf / _topo.pdf suffix) and display label
    var ROWS = [
        { tag: "go_pos_1",   label: "(a)" },
        { tag: "go_pos_2",   label: "(b)" },
        { tag: "go_neg_1",   label: "(c)" },
        { tag: "nogo_pos_1", label: "(d)" },
        { tag: "nogo_neg_1", label: "(e)" }
    ];
    var N_ROWS = ROWS.length;

    // ---- compute artboard size and grid origin -----------------------------
    var ROW_H  = ERP_H;   // row height determined by ERP panel height
    var totalW = LABEL_W + ERP_W + ERP_TOPO_GAP + TOPO_W;
    var totalH = N_ROWS * ROW_H + (N_ROWS - 1) * ROW_GAP;

    var abRect  = doc.artboards[0].artboardRect;  // [left, top, right, bottom]
    var originX = abRect[0];
    var originY = abRect[1];
    doc.artboards[0].artboardRect = [originX, originY,
                                     originX + totalW, originY - totalH];

    var gridX = originX + LABEL_W;   // left edge of ERP panels

    // convenience: Y of top edge of row ri (0-indexed)
    function rowTopY(ri) {
        return originY - ri * (ROW_H + ROW_GAP);
    }

    // ---- place ERP and topomap PDFs ----------------------------------------
    var placed = 0;
    var missing = [];

    for (var ri = 0; ri < N_ROWS; ri++) {
        var tag    = ROWS[ri].tag;
        var rowTop = rowTopY(ri);

        // -- ERP panel --
        var erpFile = new File(folder.fullName + "/" + tag + "_erp.pdf");
        if (!erpFile.exists) {
            missing.push(tag + "_erp.pdf");
        } else {
            var erpItem  = doc.placedItems.add();
            erpItem.file = erpFile;
            // scale to exact ERP_W x ERP_H
            var sx = (ERP_W / erpItem.width)  * 100;
            var sy = (ERP_H / erpItem.height) * 100;
            erpItem.resize(sx, sy);
            erpItem.position = [gridX, rowTop];
            placed++;
        }

        // -- Topomap --
        var topoFile = new File(folder.fullName + "/" + tag + "_topo.pdf");
        if (!topoFile.exists) {
            missing.push(tag + "_topo.pdf");
        } else {
            var topoItem  = doc.placedItems.add();
            topoItem.file = topoFile;
            // scale to TOPO_W x TOPO_H (square)
            var tsx = (TOPO_W / topoItem.width)  * 100;
            var tsy = (TOPO_H / topoItem.height) * 100;
            topoItem.resize(tsx, tsy);
            // centre topomap vertically within the row
            var topoLeft = gridX + ERP_W + ERP_TOPO_GAP;
            var topoTop  = rowTop - (ROW_H - TOPO_H) / 2;
            topoItem.position = [topoLeft, topoTop];
            placed++;
        }
    }

    // ---- add row labels (horizontal, centred vertically on each row) -------
    for (var ri = 0; ri < N_ROWS; ri++) {
        var rowCenterY   = rowTopY(ri) - ROW_H / 2;
        var labelCenterX = originX + LABEL_W / 2;

        var tf = doc.textFrames.add();
        tf.contents = ROWS[ri].label;
        tf.textRange.characterAttributes.size = LABEL_FONT;

        var tfW = tf.width;
        var tfH = tf.height;
        tf.position = [labelCenterX - tfW / 2,
                       rowCenterY   + tfH / 2];
    }

    // ---- fit artboard to all content ---------------------------------------
    var items = doc.pageItems;
    if (items.length > 0) {
        var minX =  Infinity, maxX = -Infinity;
        var maxY = -Infinity, minY =  Infinity;
        for (var i = 0; i < items.length; i++) {
            var gb = items[i].geometricBounds; // [left, top, right, bottom]
            if (gb[0] < minX) minX = gb[0];
            if (gb[1] > maxY) maxY = gb[1];
            if (gb[2] > maxX) maxX = gb[2];
            if (gb[3] < minY) minY = gb[3];
        }
        doc.artboards[0].artboardRect = [minX, maxY, maxX, minY];
    }

    // ---- report ------------------------------------------------------------
    var msg = "Placed " + placed + " PDFs, " + N_ROWS + " row labels.";
    if (missing.length > 0) {
        msg += "\n\nMissing files (" + missing.length + "):\n" + missing.join("\n");
    }
    alert(msg);

})();
