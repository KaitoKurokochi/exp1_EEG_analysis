// arrange_erp.jsx
// Adobe Illustrator ExtendScript
//
// Places individual row PDFs (from stat_erp_cbpt.m individual-PDF section)
// into a 5-row vertical stack on the active artboard.
//
// Each PDF contains one cluster row: ERP waveform (left) + topomap (right),
// 16 x 7 cm, matching the layout of the SVG section in stat_erp_cbpt.m.
//
// Usage:
//   1. Open (or create) an Illustrator document.
//   2. File > Scripts > Other Script... > select this file.
//   3. Choose the folder: result/fig_stat_erp_cbpt/individual/
//
// Row order (top -> bottom):
//   (a) go_pos_1   — Go,    positive cluster 1  (frontocentral,   51-109 ms)
//   (b) go_pos_2   — Go,    positive cluster 2  (parieto-occ,    113-164 ms)
//   (c) go_neg_1   — Go,    negative cluster 1  (centroparietocc, 176-258 ms)
//   (d) nogo_pos_1 — No-Go, positive cluster 1  (frontocentral,   47-141 ms)
//   (e) nogo_neg_1 — No-Go, negative cluster 1  (centroparietocc, 184-254 ms)

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
    var ROW_W     = 16.0 * PT;   // row PDF width  (must match fig_w_cm in MATLAB)
    var ROW_H     =  7.0 * PT;   // row PDF height (must match fig_h_cm in MATLAB)
    var ROW_GAP   =  0.30 * PT;  // vertical gap between rows
    var LABEL_W   =  1.00 * PT;  // horizontal space for row labels
    var LABEL_FONT = 26;          // pt

    // ---- row definitions ---------------------------------------------------
    var ROWS = [
        { tag: "go_pos_1",   label: "(a)" },
        { tag: "go_pos_2",   label: "(b)" },
        { tag: "go_neg_1",   label: "(c)" },
        { tag: "nogo_pos_1", label: "(d)" },
        { tag: "nogo_neg_1", label: "(e)" }
    ];
    var N_ROWS = ROWS.length;

    // ---- resize artboard ---------------------------------------------------
    var totalW = LABEL_W + ROW_W;
    var totalH = N_ROWS * ROW_H + (N_ROWS - 1) * ROW_GAP;

    var abRect  = doc.artboards[0].artboardRect;
    var originX = abRect[0];
    var originY = abRect[1];
    doc.artboards[0].artboardRect = [originX, originY,
                                     originX + totalW, originY - totalH];

    var gridX = originX + LABEL_W;

    function rowTopY(ri) {
        return originY - ri * (ROW_H + ROW_GAP);
    }

    // ---- place row PDFs ----------------------------------------------------
    var placed  = 0;
    var missing = [];

    for (var ri = 0; ri < N_ROWS; ri++) {
        var file = new File(folder.fullName + "/" + ROWS[ri].tag + ".pdf");
        if (!file.exists) {
            missing.push(ROWS[ri].tag + ".pdf");
            continue;
        }

        var item  = doc.placedItems.add();
        item.file = file;
        var sx = (ROW_W / item.width)  * 100;
        var sy = (ROW_H / item.height) * 100;
        item.resize(sx, sy);
        item.position = [gridX, rowTopY(ri)];
        placed++;
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
            var gb = items[i].geometricBounds;
            if (gb[0] < minX) minX = gb[0];
            if (gb[1] > maxY) maxY = gb[1];
            if (gb[2] > maxX) maxX = gb[2];
            if (gb[3] < minY) minY = gb[3];
        }
        doc.artboards[0].artboardRect = [minX, maxY, maxX, minY];
    }

    // ---- report ------------------------------------------------------------
    var msg = "Placed " + placed + " row PDFs, " + N_ROWS + " row labels.";
    if (missing.length > 0) {
        msg += "\n\nMissing files (" + missing.length + "):\n" + missing.join("\n");
    }
    alert(msg);

})();
