// arrange_topomaps.jsx  (v5)
// Adobe Illustrator ExtendScript
//
// Layout (inside each bordered box, top to bottom):
//   "Go" (large font, top)
//   0 ms  50 ms  100 ms  ...  500 ms   <- time-label row
//   Experienced                         <- group label
//   [T0] [T1] [T2] ... [T10]  [CB_grp] <- topo row + colorbar
//   Novice
//   [T0] [T1] [T2] ... [T10]  [CB_grp]
//   Difference
//   [T0] [T1] [T2] ... [T10]  [CB_diff]
//
//   No-Go box follows below with the same structure.
//
// Input folder: result/fig_freq_alpha_topo/individual/
// Expected files:
//   go_exp_NNNms.pdf, go_nov_NNNms.pdf, go_diff_NNNms.pdf   (NNN = 000..500)
//   nogo_exp_NNNms.pdf, nogo_nov_NNNms.pdf, nogo_diff_NNNms.pdf
//   colorbar_grp.pdf, colorbar_diff.pdf
//
// Usage: File > Scripts > Other Script ... > select this file

#target illustrator

(function () {

    // ------------------------------------------------------------------
    // 0.  Outer try-catch: catches errors that occur before folder dialog
    // ------------------------------------------------------------------
    try {

    // ------------------------------------------------------------------
    // 1.  Set source folder path
    // ------------------------------------------------------------------
    var folder = new Folder("C:/Users/kaito/workspace/exp1_EEG_analysis/result/fig_freq_alpha_topo/individual");
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
    // 3.  Helper functions (outside inner try for ES3 compatibility)
    // ------------------------------------------------------------------

    var _doc = doc;
    var ARIAL_FONT      = null;   // set in main layout section after font search
    var ARIAL_BOLD_FONT = null;   // set in main layout section after font search

    // Place a PDF at (x, topY). Scale to targetW x targetH if given.
    function placePDF(filePath, x, topY, targetW, targetH) {
        var file = new File(filePath);
        if (!file.exists) { return null; }
        var item  = _doc.placedItems.add();
        item.file = file;
        if (targetW !== undefined && targetH !== undefined) {
            item.resize((targetW / item.width) * 100, (targetH / item.height) * 100);
        }
        item.position = [x, topY];
        return item;
    }

    // Draw a border-only rectangle.
    function drawRect(left, top, width, height, lw) {
        var r = _doc.pathItems.rectangle(top, left, width, height);
        r.filled      = false;
        r.stroked     = true;
        r.strokeWidth = lw;
        var c = new RGBColor();
        c.red = 0; c.green = 0; c.blue = 0;
        r.strokeColor = c;
        return r;
    }

    // Add a text frame centred at (cx, cy). Applies ARIAL_FONT when available.
    function addText(str, fontSize, cx, cy) {
        var tf = _doc.textFrames.add();
        tf.contents = str;
        var ca = tf.textRange.characterAttributes;
        ca.size = fontSize;
        if (ARIAL_FONT !== null) { ca.textFont = ARIAL_FONT; }
        tf.position = [cx - tf.width / 2, cy + tf.height / 2];
        return tf;
    }

    // Add a text frame left-aligned: left edge at lx, vertically centred at cy.
    // Pass useBold=true to use Arial Bold when available.
    function addLeftText(str, fontSize, lx, cy, useBold) {
        var tf = _doc.textFrames.add();
        tf.contents = str;
        var ca = tf.textRange.characterAttributes;
        ca.size = fontSize;
        var fnt = (useBold && ARIAL_BOLD_FONT !== null) ? ARIAL_BOLD_FONT : ARIAL_FONT;
        if (fnt !== null) { ca.textFont = fnt; }
        tf.position = [lx, cy + tf.height / 2];
        return tf;
    }

    // ------------------------------------------------------------------
    // 4.  Main layout
    // ------------------------------------------------------------------
    try {

        // ---- verify RGB colour mode -----------------------------------
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

        // ---- layout parameters (cm -> points;  1 cm = 28.3465 pt) ----
        var PT           = 28.3465;
        var TOPO         = 2.96  * PT;   // topomap cell size (must match topo_cm in MATLAB)
        var FONT_SIZE        = 18;            // unified font size for all text (pt)
        var COND_H           = 0.80  * PT;   // "Go" / "No-Go" label row height
        var TIME_H           = 0.80  * PT;   // time-label row height
        var TIME_BOTTOM_GAP  = 0.30  * PT;   // extra space below time labels
        var GRP_LABEL_H      = 0.80  * PT;   // group label row height
        var TOPO_GAP         = 0.30  * PT;   // horizontal gap between topo cells in a row
        var ROW_GAP          = 0.70  * PT;   // vertical gap between topo row and next group label
        var BOX_PAD      = 0.40  * PT;   // inner padding
        var BOX_LW       = 1.5;          // border line width (pt)
        var SECTION_GAP  = 0.70  * PT;   // vertical gap between Go and No-Go boxes
        var PAD_OUTER    = 0.40  * PT;   // outer figure margin
        var CB_GAP       = 0.30  * PT;   // horizontal gap between topo grid and colorbar

        // Colorbar PDF dimensions (must match MATLAB stat_freq_cbpt_alpha colorbar section)
        //   CB_PDF_W: pad_l(0.20)+cb_w(0.40)+tick(1.00)+label_w(0.70)+pad_r(0.20) = 2.50 cm
        //   CB_PDF_H: computed dynamically in MATLAB; actual height read from cbItem.height.
        //
        //   CB_PAD_V per colorbar: eff_pad_v_cm in MATLAB =
        //     max(pad_v_cm=0.30, lbl_half_cm - topo_cm_cb/2)
        //   where char_w_cm = cb_font_sz(18)*0.60/28.3465, lbl_half_cm = nchars * char_w_cm / 2
        //
        //   "Power (db)"      10 chars -> lbl_half=1.905 cm -> eff_pad_v = max(0.30,0.425) = 0.425 cm
        //   "Difference (db)" 15 chars -> lbl_half=2.858 cm -> eff_pad_v = max(0.30,1.378) = 1.378 cm
        //
        //   Bar center from PDF bottom = eff_pad_v_cm + topo_cm_cb/2
        //   => cbTopY = rowCenterY + cbItem.height - CB_PAD_V_k - TOPO/2
        var CB_PDF_W      = 2.50  * PT;
        var CB_PAD_V_GRP  = 0.425 * PT;   // "Power (db)"      -- must match eff_pad_v_cm in MATLAB
        var CB_PAD_V_DIFF = 1.378 * PT;   // "Difference (db)" -- must match eff_pad_v_cm in MATLAB
        // Map rows [exp, nov, diff] to their colorbar bottom-pad values:
        var CB_PAD_V_BY_ROW = [CB_PAD_V_GRP, CB_PAD_V_GRP, CB_PAD_V_DIFF];

        // ---- find Arial Regular and Arial Bold --------------------------------
        var ffi, tmpName;
        ARIAL_FONT = null;
        for (ffi = 0; ffi < app.textFonts.length; ffi++) {
            tmpName = app.textFonts[ffi].name;
            if (tmpName === "ArialMT") { ARIAL_FONT = app.textFonts[ffi]; break; }
        }
        if (ARIAL_FONT === null) {
            for (ffi = 0; ffi < app.textFonts.length; ffi++) {
                tmpName = app.textFonts[ffi].name;
                if (tmpName.indexOf("Arial") === 0 && tmpName.indexOf("Bold") === -1 && tmpName.indexOf("Italic") === -1) {
                    ARIAL_FONT = app.textFonts[ffi];
                    break;
                }
            }
        }
        ARIAL_BOLD_FONT = null;
        for (ffi = 0; ffi < app.textFonts.length; ffi++) {
            tmpName = app.textFonts[ffi].name;
            if (tmpName === "Arial-BoldMT") { ARIAL_BOLD_FONT = app.textFonts[ffi]; break; }
        }
        if (ARIAL_BOLD_FONT === null) {
            for (ffi = 0; ffi < app.textFonts.length; ffi++) {
                tmpName = app.textFonts[ffi].name;
                if (tmpName.indexOf("Arial") === 0 && tmpName.indexOf("Bold") > -1 && tmpName.indexOf("Italic") === -1) {
                    ARIAL_BOLD_FONT = app.textFonts[ffi];
                    break;
                }
            }
        }

        // ---- data definitions -----------------------------------------
        var COND_KEYS   = ["go",    "nogo"];
        var COND_TITLES = ["Go Condition",    "No-Go Condition"];
        var GRP_KEYS    = ["exp",   "nov",    "diff"];
        // GRP_LABELS[ci][ri]: panel letters assigned sequentially across conditions
        //   Go:    A (Experienced), B (Novice), C (Difference)
        //   No-Go: D (Experienced), E (Novice), F (Difference)
        var GRP_LABELS  = [
            ["A (Experienced)", "B (Novice)", "C (Difference)"],
            ["D (Experienced)", "E (Novice)", "F (Difference)"]
        ];
        var CB_NAMES    = ["colorbar_grp", "colorbar_grp", "colorbar_diff"];
        var TIMES_MS    = [0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

        var NC = TIMES_MS.length;   // 11 time points = columns
        var NR = GRP_KEYS.length;   //  3 groups = rows per section

        // Row heights from actual PDF MediaBox heights (measured from generated files).
        // exportgraphics uses tight clipping, so the PDF height = rendered content height,
        // NOT the MATLAB figure height.  Values are in Illustrator points (= PDF points = 1/72 in).
        //   colorbar_grp.pdf:  MediaBox [0 0 72  98] -> 98  pt
        //   colorbar_diff.pdf: MediaBox [0 0 72 118] -> 118 pt
        var CB_ROW_H_GRP  = 98;    // pt -- update if PDF is regenerated with different font/label
        var CB_ROW_H_DIFF = 118;   // pt -- update if PDF is regenerated with different font/label
        var CB_ROW_H_BY_ROW = [CB_ROW_H_GRP, CB_ROW_H_GRP, CB_ROW_H_DIFF];

        // ---- section dimensions ---------------------------------------
        // inner width  = 11 topo cols + 10 topo gaps + cb gap + colorbar width
        // inner height = cond + time + time_bottom_gap
        //              + 3*group_label + row_heights_sum + 2*row_gaps
        var SEC_INNER_W    = NC * TOPO + (NC - 1) * TOPO_GAP + CB_GAP + CB_PDF_W;
        var SEC_ROW_H_SUM  = CB_ROW_H_GRP + CB_ROW_H_GRP + CB_ROW_H_DIFF;
        var SEC_INNER_H    = COND_H + TIME_H + TIME_BOTTOM_GAP
                           + NR * GRP_LABEL_H + SEC_ROW_H_SUM
                           + (NR - 1) * ROW_GAP;
        var SEC_BOX_W   = SEC_INNER_W + 2 * BOX_PAD;
        var SEC_BOX_H   = SEC_INNER_H + 2 * BOX_PAD;

        // ---- artboard size --------------------------------------------
        var totalW = PAD_OUTER + SEC_BOX_W + PAD_OUTER;
        var totalH = PAD_OUTER + 2 * SEC_BOX_H + SECTION_GAP + PAD_OUTER;

        var abRect  = doc.artboards[0].artboardRect;
        var originX = abRect[0];
        var originY = abRect[1];

        doc.artboards[0].artboardRect = [
            originX, originY,
            originX + totalW, originY - totalH
        ];

        // x-left of topo grid (same for all sections)
        var topoGridLeft = originX + PAD_OUTER + BOX_PAD;
        // x-left of colorbar column (after all topo cols + inter-col gaps)
        var cbLeft       = topoGridLeft + NC * TOPO + (NC - 1) * TOPO_GAP + CB_GAP;

        // ---- declare loop variables upfront (ES3 best practice) -------
        var ci, ri, ti, i;
        var boxTop, boxLeft;
        var curY, timeCY, colCX;
        var rowTopY, rowCenterY, topoTopY, rowH;
        var t_ms, pad3, fname, x, item;
        var cbPath, cbItem;
        var placed_count, missing;
        var items, minX, maxX, minY, maxY, gb;

        placed_count = 0;
        missing      = [];

        // ---- section boxes (ci=0: Go on top, ci=1: No-Go below) ------
        for (ci = 0; ci < 2; ci++) {
            boxTop  = originY - PAD_OUTER - ci * (SEC_BOX_H + SECTION_GAP);
            boxLeft = originX + PAD_OUTER;

            drawRect(boxLeft, boxTop, SEC_BOX_W, SEC_BOX_H, BOX_LW);

            // curY walks downward from the top inner edge of the box
            curY = boxTop - BOX_PAD;

            // 1. Condition label ("Go" / "No-Go")  -- left-aligned, bold
            addLeftText(COND_TITLES[ci], FONT_SIZE, topoGridLeft, curY - COND_H / 2, true);
            curY = curY - COND_H;

            // 2. Time labels (one per topo column) -- centred above each column
            timeCY = curY - TIME_H / 2;
            for (ti = 0; ti < NC; ti++) {
                colCX = topoGridLeft + ti * (TOPO + TOPO_GAP) + TOPO / 2;
                addText(TIMES_MS[ti] + " ms", FONT_SIZE, colCX, timeCY);
            }
            curY = curY - TIME_H;
            curY = curY - TIME_BOTTOM_GAP;

            // 3. Group rows (Experienced / Novice / Difference)
            for (ri = 0; ri < NR; ri++) {
                // group label -- left-aligned
                addLeftText(GRP_LABELS[ci][ri], FONT_SIZE, topoGridLeft, curY - GRP_LABEL_H / 2, true);
                curY = curY - GRP_LABEL_H;

                // --- Step 1: place colorbar first to measure actual row height ---
                // Row height = colorbar PDF height (taller than TOPO).
                // Topo cells are then centred vertically inside this row.
                rowTopY = curY;
                cbPath  = folder.fullName + "/" + CB_NAMES[ri] + ".pdf";
                cbItem  = placePDF(cbPath, cbLeft, rowTopY);   // temporary position
                if (cbItem !== null) {
                    rowH = cbItem.height;
                } else {
                    rowH = CB_ROW_H_BY_ROW[ri];   // fallback: use estimated height
                    missing.push(CB_NAMES[ri] + ".pdf");
                }

                // Row metrics derived from colorbar height
                rowCenterY = rowTopY - rowH / 2;           // vertical center of row
                topoTopY   = rowCenterY + TOPO / 2;        // top of topo cell (centred in row)

                // --- Step 2: place topo cells centred in the row ---
                for (ti = 0; ti < NC; ti++) {
                    t_ms  = TIMES_MS[ti];
                    pad3  = ("000" + t_ms).slice(-3);
                    fname = COND_KEYS[ci] + "_" + GRP_KEYS[ri] + "_" + pad3 + "ms.pdf";
                    x     = topoGridLeft + ti * (TOPO + TOPO_GAP);
                    item  = placePDF(folder.fullName + "/" + fname, x, topoTopY, TOPO, TOPO);
                    if (item !== null) { placed_count = placed_count + 1; } else { missing.push(fname); }
                }

                // --- Step 3: reposition colorbar with PDF centre at rowCenterY ---
                // exportgraphics tight-clips to content.  The rendered content
                // (bar + ticks + rotated label) is symmetric about the bar centre,
                // so PDF centre ~= bar centre.
                //   cbTopY = rowCenterY + cbItem.height / 2
                if (cbItem !== null) {
                    cbItem.position = [cbLeft, rowCenterY + cbItem.height / 2];
                }

                // Advance cursor by the full colorbar row height
                curY = curY - rowH;

                // gap between groups (not after the last group)
                if (ri < NR - 1) { curY = curY - ROW_GAP; }
            }
        }

        // ---- fit artboard to actual content + margin -----------------
        // Use geometricBounds (path only); add MARGIN so border strokes are not clipped.
        var MARGIN = 4;   // pt margin outside all content
        items = doc.pageItems;
        if (items.length > 0) {
            minX =  999999; maxX = -999999;
            maxY = -999999; minY =  999999;
            for (i = 0; i < items.length; i++) {
                gb = items[i].geometricBounds;
                if (gb[0] < minX) { minX = gb[0]; }
                if (gb[1] > maxY) { maxY = gb[1]; }
                if (gb[2] > maxX) { maxX = gb[2]; }
                if (gb[3] < minY) { minY = gb[3]; }
            }
            doc.artboards[0].artboardRect = [minX - MARGIN, maxY + MARGIN, maxX + MARGIN, minY - MARGIN];
        }

        // ---- final report --------------------------------------------
        var msg = "Done.\n\n" +
                  "Topomap PDFs placed : " + placed_count + "\n" +
                  "Missing files       : " + missing.length;
        if (missing.length > 0) {
            msg += "\n\nMissing (" + missing.length + "):\n";
            msg += missing.slice(0, 10).join("\n");
            if (missing.length > 10) { msg += "\n..."; }
        }
        alert(msg);

    } catch (e) {
        alert("Script error (layout):\n" + e.message + "\n\nLine: " + e.line);
    }

    } catch (eFatal) {
        alert("Fatal script error:\n" + eFatal.message + "\n\nLine: " + eFatal.line);
    }

})();
