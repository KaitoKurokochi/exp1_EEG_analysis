// arrange_topomaps.jsx
// Adobe Illustrator ExtendScript
//
// Places individual topomap PDFs (from stat_freq_cbpt_alpha section 3)
// into a 6-row x 11-column grid on the active artboard, with:
//   - row labels (rotated 90 deg CCW) to the left of the grid
//   - time labels (0 ms .. 500 ms) above each column
//   - colorbar PDFs (colorbar_grp / colorbar_diff) to the right of each row
//     (one per row; delete duplicates as needed in Illustrator)
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

    // ---- verify document colour mode is RGB ---------------------------------
    // MATLAB's exportgraphics writes DeviceRGB PDFs (no ICC profile).
    // Placing an untagged RGB PDF into a CMYK document triggers Illustrator's
    // RGB->CMYK conversion, which clips/shifts the jet colormap's saturated
    // primaries and causes visible colour distortion.
    // The document MUST be in RGB mode for colours to pass through unchanged.
    if (doc.documentColorSpace !== DocumentColorSpace.RGB) {
        var switchNow = confirm(
            "This document is in CMYK mode.\n\n" +
            "The topomap PDFs use RGB colours (DeviceRGB, no ICC profile).\n" +
            "Placing them into a CMYK document causes Illustrator to convert\n" +
            "colours, which distorts the jet colormap.\n\n" +
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
    var PT         = 28.3465;
    var TOPO       = 2.96 * PT;   // topomap cell size (must match topo_cm in MATLAB)
    var ROW_GAP    = 0.50 * PT;   // vertical gap between rows
    var LABEL_W    = 1.20 * PT;   // horizontal space for rotated row labels
    var TIME_H     = 0.90 * PT;   // vertical space for time labels above the grid
    var CB_GAP     = 0.30 * PT;   // gap between last topomap column and colorbar

    // Natural colorbar PDF dimensions (must match MATLAB output):
    //   fig_cb_w = pad_l + cb_w + tick + pad_r = 0.20+0.40+1.00+0.20 = 1.80 cm
    //   fig_cb_h = topo_cm + 2*pad_v = 2.96 + 0.60 = 3.56 cm
    var CB_PDF_W   = 1.80 * PT;
    var CB_PDF_H   = 3.56 * PT;

    var LABEL_FONT = 8;   // pt — row labels
    var TIME_FONT  = 8;   // pt — time-axis labels

    // ---- row and column metadata -------------------------------------------
    var ROW_NAMES = [
        "go_exp",  "go_nov",  "go_diff",
        "nogo_exp","nogo_nov","nogo_diff"
    ];
    var ROW_LABELS = [
        "Experienced (Go)",
        "Novice (Go)",
        "Experienced − Novice (Go)",
        "Experienced (No-Go)",
        "Novice (No-Go)",
        "Experienced − Novice (No-Go)"
    ];
    // colorbar filename (without .pdf) for each row
    var CB_NAMES = [
        "colorbar_grp","colorbar_grp","colorbar_diff",
        "colorbar_grp","colorbar_grp","colorbar_diff"
    ];
    var TIMES_MS = [0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

    // ---- compute artboard size and grid origin -----------------------------
    var totalW = LABEL_W + TIMES_MS.length * TOPO + CB_GAP + CB_PDF_W;
    var totalH = TIME_H  + ROW_NAMES.length * TOPO + (ROW_NAMES.length - 1) * ROW_GAP;

    var abRect  = doc.artboards[0].artboardRect;  // [left, top, right, bottom]
    var originX = abRect[0];
    var originY = abRect[1];   // top edge (Y increases upward in Illustrator)

    doc.artboards[0].artboardRect = [originX, originY,
                                     originX + totalW, originY - totalH];

    // top-left corner of the topomap grid (after label column and time header)
    var gridX = originX + LABEL_W;
    var gridY = originY - TIME_H;

    // convenience: Y of the top edge of row ri
    function rowTopY(ri) {
        return gridY - ri * (TOPO + ROW_GAP);
    }

    // ---- place topomap PDFs ------------------------------------------------
    var placed_count = 0;
    var missing      = [];

    for (var ri = 0; ri < ROW_NAMES.length; ri++) {
        for (var ti = 0; ti < TIMES_MS.length; ti++) {

            var t_ms  = TIMES_MS[ti];
            var pad   = ("000" + t_ms).slice(-3);
            var fname = ROW_NAMES[ri] + "_" + pad + "ms.pdf";
            var file  = new File(folder.fullName + "/" + fname);

            if (!file.exists) { missing.push(fname); continue; }

            var x = gridX + ti * TOPO;
            var y = rowTopY(ri);

            var item  = doc.placedItems.add();
            item.file = file;
            var scaleX = (TOPO / item.width)  * 100;
            var scaleY = (TOPO / item.height) * 100;
            item.resize(scaleX, scaleY);
            item.position = [x, y];
            // Note: embed() is intentionally omitted.
            // Colour correctness is enforced by the RGB mode check above.

            placed_count++;
        }
    }

    // ---- place colorbar PDFs (one per row, at natural size) ----------------
    // The colorbar is vertically centred on its row.
    // Rows sharing the same scale (grp or diff) will have identical colorbars
    // stacked — delete the duplicates manually in Illustrator as needed.
    var cbX = gridX + TIMES_MS.length * TOPO + CB_GAP;
    var cb_placed = 0;

    for (var ri = 0; ri < ROW_NAMES.length; ri++) {
        var cbFile = new File(folder.fullName + "/" + CB_NAMES[ri] + ".pdf");
        if (!cbFile.exists) { missing.push(CB_NAMES[ri] + ".pdf"); continue; }

        // vertical centre of the row; align colorbar centre to row centre
        var rowCenterY = rowTopY(ri) - TOPO / 2;
        var cbTopY     = rowCenterY + CB_PDF_H / 2;

        var cbItem  = doc.placedItems.add();
        cbItem.file = cbFile;
        // placed at natural size — no resize (avoids distorting tick labels)
        cbItem.position = [cbX, cbTopY];
        cb_placed++;
    }

    // ---- add time labels above each column ---------------------------------
    for (var ti = 0; ti < TIMES_MS.length; ti++) {
        var colCenterX = gridX + ti * TOPO + TOPO / 2;

        var tf = doc.textFrames.add();
        tf.contents = TIMES_MS[ti] + " ms";
        tf.textRange.characterAttributes.size = TIME_FONT;

        var tfW = tf.width;
        var tfH = tf.height;
        // centre horizontally over column; centre vertically in the TIME_H band
        tf.position = [colCenterX - tfW / 2,
                       originY - (TIME_H - tfH) / 2];
    }

    // ---- add row labels (rotated 90 deg CCW) to the left of the grid ------
    for (var ri = 0; ri < ROW_NAMES.length; ri++) {
        var rowCenterY   = rowTopY(ri) - TOPO / 2;
        var labelCenterX = originX + LABEL_W / 2;

        var tf = doc.textFrames.add();
        tf.contents = ROW_LABELS[ri];
        tf.textRange.characterAttributes.size = LABEL_FONT;

        // Rotate 90 deg CCW around the item's own centre so text reads
        // from bottom to top (standard axis-label orientation).
        tf.rotate(90);

        // After rotation: tf.width ~ original text height, tf.height ~ original text width.
        // Centre the rotated frame on (labelCenterX, rowCenterY).
        tf.position = [labelCenterX - tf.width  / 2,
                       rowCenterY   + tf.height / 2];
    }

    // ---- report ------------------------------------------------------------
    var msg = "Placed " + placed_count + " topomap PDFs, " +
              cb_placed + " colorbar PDFs, " +
              TIMES_MS.length + " time labels, " +
              ROW_NAMES.length + " row labels.";
    if (missing.length > 0) {
        msg += "\n\nMissing files (" + missing.length + "):\n";
        msg += missing.slice(0, 8).join("\n");
        if (missing.length > 8) { msg += "\n..."; }
    }
    alert(msg);

})();
