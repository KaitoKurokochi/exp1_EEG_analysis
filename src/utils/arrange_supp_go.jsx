// arrange_supp_go.jsx  (v3)
// Adobe Illustrator ExtendScript
//
// Places individual band-specific diff topomap PDFs (from stat_freq_cbpt.m section 3)
// into a 5-row x 11-column panel grid on the active artboard.
// This script is for the Go condition supplementary figure.
//
// Frequency bands follow Minami et al. (2024).
//
// Layout (top -> bottom):
//   Row 0  : time labels  (0 ms ... 500 ms)              height = TIME_H
//   [for each of 5 frequency bands:]
//   Row i  : band label (left-aligned, bold)              height = PANEL_LABEL_H
//   Row i  : topomap row + colorbar  (height = cbItem.height)
//   gap    : ROW_GAP (between rows, not after last)
//
// Row order:   Theta / alpha / beta / Low_gamma / High_gamma
// Col order:   0 ms, 50 ms, ... 500 ms  (11 columns)
//
// Prerequisites:
//   Run erp_to_freq_bands.m, then stat_freq_cbpt.m section 3.
//   Source PDFs must be in: result/fig_freq_overview_topo/go_individual/
//
// Usage:
//   File > Scripts > Other Script... > select this file

#target illustrator

(function () {

    // ------------------------------------------------------------------
    // Outer try-catch
    // ------------------------------------------------------------------
    try {

    // ------------------------------------------------------------------
    // 1.  Set source folder path
    // ------------------------------------------------------------------
    var folder = new Folder("C:/Users/kaito/workspace/exp1_EEG_analysis/result/fig_freq_overview_topo/go_individual");
    if (!folder.exists) {
        alert("Folder not found:\n" + folder.fullName);
        return;
    }

    // ------------------------------------------------------------------
    // 2.  Get active document
    // ------------------------------------------------------------------
    var doc;
    try {
        doc = app.activeDocument;
    } catch (e2) {
        alert("Error: No Illustrator document is open.\nPlease open a document and run the script again.");
        return;
    }

    // ------------------------------------------------------------------
    // 3.  Layout
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
        var ROW_GAP       = 0.70 * PT;   // gap between bottom of topo row and next panel label
        var COL_GAP       = 0.30 * PT;   // horizontal gap between topomap columns
        var TIME_H        = 1.20 * PT;   // height of time-label header row
        var PANEL_LABEL_H = 0.60 * PT;   // height of panel-letter row
        var CB_GAP        = 0.30 * PT;   // gap between last topomap column and colorbar

        // Colorbar PDF width (must match stat_freq_cbpt.m):
        //   pad_l(0.20) + cb_w(0.40) + tick(1.00) + label_w(0.70) + pad_r(0.20) = 2.50 cm
        var CB_PDF_W = 2.50 * PT;

        var FONT_SIZE = 18;   // pt

        // ---- find Arial Regular and Arial Bold -------------------------
        var ARIAL_FONT = null, ARIAL_BOLD_FONT = null;
        var ffi, tmpName;
        for (ffi = 0; ffi < app.textFonts.length; ffi++) {
            tmpName = app.textFonts[ffi].name;
            if (tmpName === "ArialMT") { ARIAL_FONT = app.textFonts[ffi]; break; }
        }
        if (ARIAL_FONT === null) {
            for (ffi = 0; ffi < app.textFonts.length; ffi++) {
                tmpName = app.textFonts[ffi].name;
                if (tmpName.indexOf("Arial") === 0 && tmpName.indexOf("Bold") === -1 && tmpName.indexOf("Italic") === -1) {
                    ARIAL_FONT = app.textFonts[ffi]; break;
                }
            }
        }
        for (ffi = 0; ffi < app.textFonts.length; ffi++) {
            tmpName = app.textFonts[ffi].name;
            if (tmpName === "Arial-BoldMT") { ARIAL_BOLD_FONT = app.textFonts[ffi]; break; }
        }
        if (ARIAL_BOLD_FONT === null) {
            for (ffi = 0; ffi < app.textFonts.length; ffi++) {
                tmpName = app.textFonts[ffi].name;
                if (tmpName.indexOf("Arial") === 0 && tmpName.indexOf("Bold") > -1 && tmpName.indexOf("Italic") === -1) {
                    ARIAL_BOLD_FONT = app.textFonts[ffi]; break;
                }
            }
        }

        // ---- data definitions -----------------------------------------
        var ROW_NAMES  = ["Theta", "alpha", "beta", "Low_gamma", "High_gamma"];
        var ROW_LABELS = ["theta", "alpha", "beta", "low-gamma", "high-gamma"];
        var TIMES_MS   = [0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

        var NR = ROW_NAMES.length;   // 5
        var NC = TIMES_MS.length;    // 11

        // ---- artboard origin -------------------------------------------
        var abRect  = doc.artboards[0].artboardRect;
        var originX = abRect[0];
        var originY = abRect[1];

        // ---- topo grid X and colorbar X --------------------------------
        var gridX = originX;
        var cbX   = gridX + NC * TOPO + (NC - 1) * COL_GAP + CB_GAP;

        // ---- declare loop variables (ES3) ------------------------------
        var ri, ti;
        var cbFile, cbItem, rowH, rowTopY, rowCenterY, topoTopY_ri;
        var x, item, fname, pad3, tfile;
        var plabel, pca, boldFnt, plH, bandCenterY;
        var tlabel, tca, colCX;
        var i, gb;

        var placed_count = 0;
        var cb_placed    = 0;
        var missing      = [];

        // ---- cursor walks downward from top ----------------------------
        var curY = originY;

        // ---- time labels -----------------------------------------------
        for (ti = 0; ti < NC; ti++) {
            colCX  = gridX + ti * (TOPO + COL_GAP) + TOPO / 2;
            tlabel = doc.textFrames.add();
            tlabel.contents = TIMES_MS[ti] + " ms";
            tca = tlabel.textRange.characterAttributes;
            tca.size = FONT_SIZE;
            if (ARIAL_FONT !== null) { tca.textFont = ARIAL_FONT; }
            tlabel.position = [colCX - tlabel.width / 2, curY - (TIME_H - tlabel.height) / 2];
        }
        curY = curY - TIME_H;

        // ---- band rows -------------------------------------------------
        for (ri = 0; ri < NR; ri++) {

            // -- panel label (bold, left-aligned) --
            plabel = doc.textFrames.add();
            plabel.contents = ROW_LABELS[ri];
            pca = plabel.textRange.characterAttributes;
            pca.size = FONT_SIZE;
            boldFnt = (ARIAL_BOLD_FONT !== null) ? ARIAL_BOLD_FONT : ARIAL_FONT;
            if (boldFnt !== null) { pca.textFont = boldFnt; }
            plH = plabel.height;
            bandCenterY = curY - PANEL_LABEL_H / 2;
            plabel.position = [gridX, bandCenterY + plH / 2];
            curY = curY - PANEL_LABEL_H;

            // -- place colorbar first to measure actual row height --
            rowTopY = curY;
            cbFile  = new File(folder.fullName + "/colorbar_" + ROW_NAMES[ri] + ".pdf");
            cbItem  = null;
            if (cbFile.exists) {
                cbItem = doc.placedItems.add();
                cbItem.file = cbFile;
                cbItem.position = [cbX, rowTopY];   // temporary
                cb_placed++;
            } else {
                missing.push("colorbar_" + ROW_NAMES[ri] + ".pdf");
            }

            rowH        = (cbItem !== null) ? cbItem.height : TOPO;
            rowCenterY  = rowTopY - rowH / 2;
            topoTopY_ri = rowCenterY + TOPO / 2;

            // -- reposition colorbar centred on row --
            if (cbItem !== null) {
                cbItem.position = [cbX, rowCenterY + cbItem.height / 2];
            }

            // -- place topo cells --
            for (ti = 0; ti < NC; ti++) {
                pad3  = ("000" + TIMES_MS[ti]).slice(-3);
                fname = ROW_NAMES[ri] + "_" + pad3 + "ms.pdf";
                x     = gridX + ti * (TOPO + COL_GAP);
                tfile = new File(folder.fullName + "/" + fname);
                if (tfile.exists) {
                    item = doc.placedItems.add();
                    item.file = tfile;
                    item.resize((TOPO / item.width) * 100, (TOPO / item.height) * 100);
                    item.position = [x, topoTopY_ri];
                    placed_count++;
                } else {
                    missing.push(fname);
                }
            }

            curY = curY - rowH;
            if (ri < NR - 1) { curY = curY - ROW_GAP; }
        }

        // ---- fit artboard to actual content ----------------------------
        var items = doc.pageItems;
        if (items.length > 0) {
            var minX =  1e18, maxX = -1e18;
            var maxY = -1e18, minY =  1e18;
            for (i = 0; i < items.length; i++) {
                gb = items[i].geometricBounds;
                if (gb[0] < minX) { minX = gb[0]; }
                if (gb[1] > maxY) { maxY = gb[1]; }
                if (gb[2] > maxX) { maxX = gb[2]; }
                if (gb[3] < minY) { minY = gb[3]; }
            }
            doc.artboards[0].artboardRect = [minX, maxY, maxX, minY];
        }

        // ---- report ----------------------------------------------------
        var msg = "Go condition - supplementary figure: Done.\n\n" +
                  "Topomap PDFs placed : " + placed_count + "\n" +
                  "Colorbar PDFs placed: " + cb_placed    + "\n" +
                  "Time labels         : " + NC           + "\n" +
                  "Panel labels        : " + NR;
        if (missing.length > 0) {
            msg += "\n\nMissing files (" + missing.length + "):\n";
            msg += missing.slice(0, 10).join("\n");
            if (missing.length > 10) { msg += "\n..."; }
        }
        alert(msg);

    } catch (e) {
        alert("Script error:\n" + e.message + "\nLine: " + e.line);
    }

    } catch (eFatal) {
        alert("Fatal error:\n" + eFatal.message + "\nLine: " + eFatal.line);
    }

})();
