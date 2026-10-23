// arrange_alpha_diff_poster.jsx
// Adobe Illustrator ExtendScript
//
// Poster version of arrange_topomaps.jsx: difference topomaps only (Experienced - Novice),
// 100-350 ms, no bordered boxes, one colorbar per row.
// Time labels are not drawn (added in PowerPoint).
//
// Layout:
//   Go         [T]     [T]     ...  [T]     [CB_diff]
//   No-Go      [T]     [T]     ...  [T]     [CB_diff]
//
// Input folder (set in section 1): result/fig_freq_alpha_topo/individual/
// Expected files:
//   go_diff_NNNms.pdf, nogo_diff_NNNms.pdf   (NNN = 100..350 step 50)
//   colorbar_diff_nolabel.pdf   (from stat_freq_cbpt_alpha.m; label is drawn here in Arial)
//
// Usage: open an RGB document, then File > Scripts > Other Script ... > select this file

#target illustrator

(function () {

    try {

    // ------------------------------------------------------------------
    // 1.  Source folder and active document
    // ------------------------------------------------------------------
    var folder = new Folder("C:/Users/kaito/repos/exp1_EEG_analysis/result/fig_freq_alpha_topo/individual");
    if (!folder.exists) {
        alert("Folder not found:\n" + folder.fullName);
        return;
    }

    var doc;
    try {
        doc = app.activeDocument;
    } catch (e2) {
        alert("Error: No Illustrator document is open.\nPlease open a document and run the script again.");
        return;
    }

    // ------------------------------------------------------------------
    // 2.  Helper functions
    // ------------------------------------------------------------------
    var _doc = doc;
    var ARIAL_FONT      = null;
    var ARIAL_BOLD_FONT = null;

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

    // Text frame centred at (cx, cy), rotated by rotateDeg (counter-clockwise; 0 = none).
    function addText(str, fontSize, cx, cy, useBold, rotateDeg) {
        var tf = _doc.textFrames.add();
        tf.contents = str;
        var ca = tf.textRange.characterAttributes;
        ca.size = fontSize;
        var fnt = (useBold && ARIAL_BOLD_FONT !== null) ? ARIAL_BOLD_FONT : ARIAL_FONT;
        if (fnt !== null) { ca.textFont = fnt; }
        if (rotateDeg !== 0) { tf.rotate(rotateDeg); }
        var gb = tf.geometricBounds;   // [left, top, right, bottom]
        tf.translate(cx - (gb[0] + gb[2]) / 2, cy - (gb[1] + gb[3]) / 2);
        return tf;
    }

    // ------------------------------------------------------------------
    // 3.  Main layout
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
        var PT          = 28.3465;
        var TOPO        = 2.96 * PT;   // topomap cell size (must match topo_cm_cb in stat_freq_cbpt_alpha.m)
        var FONT_SIZE   = 18;          // pt
        var LABEL_W     = 1.00 * PT;   // row-label column width ("Go" / "No-Go", rotated)
        var TOPO_GAP    = 0.80 * PT;   // horizontal gap between topo cells
        var ROW_GAP     = 0.30 * PT;   // vertical gap between rows
        var CB_GAP      = 0.30 * PT;   // gap between topo grid and colorbar
        var MARGIN      = 4;           // pt margin around content (artboard fit)

        // ---- find Arial Regular and Arial Bold --------------------------------
        var ffi, tmpName;
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
        var COND_KEYS   = ["go", "nogo"];
        var COND_LABELS = ["Go", "No-Go"];
        var TIMES_MS    = [100, 150, 200, 250, 300, 350];
        var NC = TIMES_MS.length;
        var NR = COND_KEYS.length;

        // Fallback colorbar PDF height (pt) if the file is missing: MediaBox [0 0 53 98]
        var CB_ROW_H_FALLBACK = 98;
        var CB_LABEL_GAP      = 22;   // pt, colorbar PDF right edge (incl. tick labels) to centre of the rotated label
        var CB_LABEL          = "\u0394Power (dB)";   // Greek capital delta, as a unicode escape (ASCII source)

        var abRect  = doc.artboards[0].artboardRect;
        var originX = abRect[0];
        var originY = abRect[1];

        var topoGridLeft = originX + MARGIN + LABEL_W;
        var cbLeft       = topoGridLeft + NC * TOPO + (NC - 1) * TOPO_GAP + CB_GAP;

        var ri, ti, i;
        var curY, rowTopY, rowCenterY, rowH;
        var t_ms, pad3, fname, x, item, cbItem, cbW;
        curY = originY - MARGIN;
        var placed_count = 0;
        var missing = [];
        var items, minX, maxX, minY, maxY, gb;
        var bi, bg, white;
        var whiteBoxes = [];   // [left, top, width, height] behind each placed PDF

        // One row per condition: row label, topomaps, colorbar
        for (ri = 0; ri < NR; ri++) {
            rowTopY = curY;

            // Colorbar first, to measure the row height
            cbItem = placePDF(folder.fullName + "/colorbar_diff_nolabel.pdf", cbLeft, rowTopY);
            if (cbItem !== null) {
                rowH = cbItem.height;
                cbW  = cbItem.width;
            } else {
                rowH = CB_ROW_H_FALLBACK;
                cbW  = 0;
                missing.push("colorbar_diff_nolabel.pdf");
            }
            rowCenterY = rowTopY - rowH / 2;

            for (ti = 0; ti < NC; ti++) {
                t_ms  = TIMES_MS[ti];
                pad3  = ("000" + t_ms).slice(-3);
                fname = COND_KEYS[ri] + "_diff_" + pad3 + "ms.pdf";
                x     = topoGridLeft + ti * (TOPO + TOPO_GAP);
                item  = placePDF(folder.fullName + "/" + fname, x, rowCenterY + TOPO / 2, TOPO, TOPO);
                if (item !== null) {
                    placed_count = placed_count + 1;
                    whiteBoxes.push([x, rowCenterY + TOPO / 2, TOPO, TOPO]);
                } else { missing.push(fname); }
            }

            // Colorbar PDF centre = bar centre (content is symmetric about the bar)
            if (cbItem !== null) {
                cbItem.position = [cbLeft, rowCenterY + cbItem.height / 2];
                whiteBoxes.push([cbLeft, rowCenterY + cbItem.height / 2, cbItem.width, cbItem.height]);
            }

            addText(COND_LABELS[ri], FONT_SIZE, originX + MARGIN + LABEL_W / 2, rowCenterY, true, 90);
            addText(CB_LABEL, FONT_SIZE, cbLeft + cbW + CB_LABEL_GAP, rowCenterY, false, 270);

            curY = curY - rowH - ROW_GAP;
        }

        // ---- embed placed PDFs as native vector art -------------------
        // Linked PDFs are rasterised to PNG on SVG export (transparency artefacts);
        // embedded PDFs stay vector.
        var emb_count = 0;
        for (i = doc.placedItems.length - 1; i >= 0; i--) {
            try {
                doc.placedItems[i].embed();
                emb_count = emb_count + 1;
            } catch (eEmb) {
                alert("Embed failed:\n" + eEmb.message + "\n\nLine: " + eEmb.line);
            }
        }

        // ---- fit artboard to content ---------------------------------
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

            // White box behind each placed PDF; margins and labels stay transparent
            white = new RGBColor();
            white.red = 255; white.green = 255; white.blue = 255;

            for (bi = 0; bi < whiteBoxes.length; bi++) {
                bg = doc.pathItems.rectangle(whiteBoxes[bi][1], whiteBoxes[bi][0],
                                             whiteBoxes[bi][2], whiteBoxes[bi][3]);
                bg.fillColor = white;
                bg.stroked   = false;
                bg.zOrder(ZOrderMethod.SENDTOBACK);
            }
        }

        var msg = "Done.\n\n" +
                  "Topomap PDFs placed : " + placed_count + " / " + (NC * NR) + "\n" +
                  "Embedded as vector  : " + emb_count + "\n" +
                  "Missing files       : " + missing.length;
        if (missing.length > 0) {
            msg += "\n\nMissing:\n" + missing.slice(0, 10).join("\n");
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
