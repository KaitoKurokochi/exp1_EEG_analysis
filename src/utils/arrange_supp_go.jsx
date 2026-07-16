// arrange_supp_go.jsx  (v2)
// Adobe Illustrator ExtendScript
//
// Places individual band-specific diff topomap PDFs (from stat_freq_cbpt.m section 4)
// into a 6-row x 11-column panel grid on the active artboard.
// This script is for the Go condition supplementary figure.
//
// Frequency bands follow Minami et al. (2024); each band uses 5 log-spaced
// frequency points (following Minami & Amano, 2017).
//
// Layout (top -> bottom):
//   Row 0  : time labels  (0 ms ... 500 ms)               height = TIME_H
//   [for each of 6 frequency bands:]
//   Row i  : band label (left-aligned)                     height = PANEL_LABEL_H
//   Row i  : topomap row (11 cells) + colorbar on right   height = TOPO
//   gap    : ROW_GAP
//
// Row order:   delta / Theta / alpha / beta / Low_gamma / High_gamma
// Col order:   0 ms, 50 ms, ... 500 ms  (11 columns)
//
// Prerequisites:
//   Run erp_to_freq_bands.m, then stat_freq_cbpt.m section 4.
//   Source PDFs must be in: result/fig_freq_overview_topo/go_individual/
//
// Usage:
//   File > Scripts > Other Script... > select this file
//   Select the folder: result/fig_freq_overview_topo/go_individual/

#target illustrator

(function () {

    // ------------------------------------------------------------------
    // 1.  Select source folder FIRST (before touching the document)
    // ------------------------------------------------------------------
    var folder = Folder.selectDialog(
        "Select the 'go_individual' folder  (result/fig_freq_overview_topo/go_individual)"
    );
    if (!folder) {
        alert("No folder selected. Script cancelled.");
        return;
    }

    // ------------------------------------------------------------------
    // 2.  Get active document
    // ------------------------------------------------------------------
    var doc;
    try {
        doc = app.activeDocument;
    } catch (e) {
        alert("Error: No Illustrator document is open.\nPlease open a document and run the script again.");
        return;
    }

    // ------------------------------------------------------------------
    // 3.  Wrap everything in try-catch for clear error reporting
    // ------------------------------------------------------------------
    try {

        // ---- verify RGB colour mode ------------------------------------
        if (doc.documentColorSpace !== DocumentColorSpace.RGB) {
            var switchNow = confirm(
                "This document is in CMYK mode.\n\n" +
                "The topomap PDFs use RGB colours (DeviceRGB, no ICC profile).\n" +
                "Placing them into a CMYK document causes colour distortion.\n\n" +
                "Switch to RGB Color mode now?"
            );
            if (switchNow) {
                app.executeMenuCommand("doc-color-rgb");
            } else {
                alert("Aborted. Please switch to RGB Color mode manually and re-run.");
                return;
            }
        }

        // ---- layout parameters (cm -> points;  1 cm = 28.3465 pt) ------
        var PT            = 28.3465;
        var TOPO          = 2.96 * PT;   // topomap cell size (matches topo_cm in MATLAB)
        var ROW_GAP       = 1.00 * PT;   // gap between bottom of topo row and next panel label
        var COL_GAP       = 0.50 * PT;   // horizontal gap between topomap columns
        var TIME_H        = 1.20 * PT;   // height of time-label header row
        var PANEL_LABEL_H = 0.60 * PT;   // height of panel-letter row
        var CB_GAP        = 0.30 * PT;   // gap between last topomap column and colorbar

        // Colorbar PDF natural dimensions (must match MATLAB stat_freq_cbpt output):
        //   width  = pad_l + cb_w + tick + pad_r = 0.20 + 0.40 + 1.00 + 0.20 = 1.80 cm
        //   height = topo_cm + 2*pad_v           = 2.96 + 2*0.30             = 3.56 cm
        var CB_PDF_W = 1.80 * PT;
        var CB_PDF_H = 3.56 * PT;

        var PANEL_FONT = 26;   // pt — panel letter labels
        var TIME_FONT  = 20;   // pt — time-axis labels

        // ---- row / column metadata ------------------------------------
        var ROW_NAMES  = ["delta", "Theta", "alpha", "beta", "Low_gamma", "High_gamma"];
        var ROW_LABELS = ["delta", "theta", "alpha", "beta", "low-gamma", "high-gamma"];
        var TIMES_MS   = [0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

        var NR = ROW_NAMES.length;   // 6
        var NC = TIMES_MS.length;    // 11

        // ---- artboard size -------------------------------------------
        // Total width:  11 topos + 10 column gaps + CB_GAP + colorbar
        // Total height: time header + 6 * (panel label + topo) + 5 * row gap
        var totalW = NC * TOPO + (NC - 1) * COL_GAP + CB_GAP + CB_PDF_W;
        var totalH = TIME_H + NR * (PANEL_LABEL_H + TOPO) + (NR - 1) * ROW_GAP;

        var abRect  = doc.artboards[0].artboardRect;  // [left, top, right, bottom]
        var originX = abRect[0];
        var originY = abRect[1];   // top-left corner of artboard

        doc.artboards[0].artboardRect = [
            originX, originY,
            originX + totalW, originY - totalH
        ];

        // Grid origin: X = originX, Y = just below the time header
        var gridX = originX;
        var gridY = originY - TIME_H;   // Y of top of first panel-label row

        // Y helpers (Illustrator: Y increases upward, so top > bottom)
        //   panelLabelTopY(ri) : top edge of the panel-letter row for band ri
        //   topoTopY(ri)       : top edge of the topomap row for band ri
        function panelLabelTopY(ri) {
            return gridY - ri * (PANEL_LABEL_H + TOPO + ROW_GAP);
        }
        function topoTopY(ri) {
            return panelLabelTopY(ri) - PANEL_LABEL_H;
        }

        // ---- place topomap PDFs -------------------------------------
        var placed_count = 0;
        var missing      = [];

        for (var ri = 0; ri < NR; ri++) {
            for (var ti = 0; ti < NC; ti++) {
                var t_ms  = TIMES_MS[ti];
                var pad   = ("000" + t_ms).slice(-3);          // e.g. "050"
                var fname = ROW_NAMES[ri] + "_" + pad + "ms.pdf";
                var file  = new File(folder.fullName + "/" + fname);

                if (!file.exists) { missing.push(fname); continue; }

                var x = gridX + ti * (TOPO + COL_GAP);
                var y = topoTopY(ri);

                var item  = doc.placedItems.add();
                item.file = file;
                // Scale to fit the TOPO cell
                var sx = (TOPO / item.width)  * 100;
                var sy = (TOPO / item.height) * 100;
                item.resize(sx, sy);
                item.position = [x, y];

                placed_count++;
            }
        }

        // ---- place colorbar PDFs (one per row, at natural size) -----
        var cbX       = gridX + NC * TOPO + (NC - 1) * COL_GAP + CB_GAP;
        var cb_placed = 0;

        for (var ri = 0; ri < NR; ri++) {
            var cbFile = new File(folder.fullName + "/colorbar_" + ROW_NAMES[ri] + ".pdf");
            if (!cbFile.exists) { missing.push("colorbar_" + ROW_NAMES[ri] + ".pdf"); continue; }

            // Vertically centre the colorbar on the topomap row
            var topoCenterY = topoTopY(ri) - TOPO / 2;
            var cbTopY      = topoCenterY + CB_PDF_H / 2;

            var cbItem  = doc.placedItems.add();
            cbItem.file = cbFile;
            cbItem.position = [cbX, cbTopY];   // place at natural size
            cb_placed++;
        }

        // ---- add time labels above each column ----------------------
        for (var ti = 0; ti < NC; ti++) {
            var colCenterX = gridX + ti * (TOPO + COL_GAP) + TOPO / 2;

            var tlabel = doc.textFrames.add();
            tlabel.contents = TIMES_MS[ti] + " ms";
            tlabel.textRange.characterAttributes.size = TIME_FONT;

            var tlW = tlabel.width;
            var tlH = tlabel.height;
            tlabel.position = [
                colCenterX - tlW / 2,
                originY - (TIME_H - tlH) / 2
            ];
        }

        // ---- add panel letter labels (left-aligned, one per band) ---
        for (var ri = 0; ri < NR; ri++) {
            var plabel = doc.textFrames.add();
            plabel.contents = ROW_LABELS[ri];
            plabel.textRange.characterAttributes.size = PANEL_FONT;

            var plH = plabel.height;
            // Vertically centre within the PANEL_LABEL_H band
            var bandCenterY = panelLabelTopY(ri) - PANEL_LABEL_H / 2;
            plabel.position = [gridX, bandCenterY + plH / 2];
        }

        // ---- fit artboard to actual content -------------------------
        var items = doc.pageItems;
        if (items.length > 0) {
            var minX =  1e18, maxX = -1e18;
            var maxY = -1e18, minY =  1e18;
            for (var i = 0; i < items.length; i++) {
                var gb = items[i].geometricBounds;  // [left, top, right, bottom]
                if (gb[0] < minX) { minX = gb[0]; }
                if (gb[1] > maxY) { maxY = gb[1]; }
                if (gb[2] > maxX) { maxX = gb[2]; }
                if (gb[3] < minY) { minY = gb[3]; }
            }
            doc.artboards[0].artboardRect = [minX, maxY, maxX, minY];
        }

        // ---- final report -------------------------------------------
        var msg = "Go condition — supplementary figure: Done.\n\n" +
                  "Topomap PDFs placed : " + placed_count + "\n" +
                  "Colorbar PDFs placed: " + cb_placed    + "\n" +
                  "Time labels         : " + NC           + "\n" +
                  "Panel labels (a-f)  : " + NR;
        if (missing.length > 0) {
            msg += "\n\nMissing files (" + missing.length + "):\n";
            msg += missing.slice(0, 10).join("\n");
            if (missing.length > 10) { msg += "\n..."; }
        }
        alert(msg);

    } catch (e) {
        alert("Script error:\n" + e.message + "\n\nLine: " + e.line);
    }

})();
