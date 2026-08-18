// arrange_erp.jsx
// Adobe Illustrator ExtendScript
//
// Place Go and No-Go ERP panels side-by-side in a single document.
// Each condition is placed in its own bordered box:
//
//   [Go trials box]  [GAP_COND]  [No-Go trials box]
//
// Inside each box:
//   [LABEL_AREA: "Go trials" / "No-Go trials" label (bold)]
//   [PAD]
//   [ERP row 1: waveform | topomap]
//   ...
//   [legend (right-aligned, placed at natural size)]
//   [PAD]
//
// Scaling strategy:
//   ERP panels: MATLAB outputs a dynamically-sized tight bounding box PDF
//   (exact content size, no wasted margins, no clipping).  Illustrator
//   scales each ERP panel to ERP_W (10 cm) via resize() so that all rows
//   align precisely regardless of small panel-to-panel width variation.
//   erpScaleFactor is captured from the first ERP panel and reused for the
//   legend and condition label.
//
//   Topomaps: MATLAB outputs at exactly topo_cm x topo_cm (4.5 x 4.5 cm).
//   Placed at natural size — no resize() needed.
//
//   Legend: MATLAB auto-sizes to content; placed at natural size after
//   being scaled by erpScaleFactor to match ERP visual font size.
//
// Equal-height boxes:
//   All condition boxes share the same height regardless of how many
//   cluster rows each condition has.  The Go (ci=0) box bottom is saved
//   as goBoxBottom and applied to subsequent conditions when their
//   natural bottom would be higher (i.e. fewer rows).
//
// Bounds tracking:
//   Bounding box per condition is updated INLINE immediately after each
//   item is positioned.  This avoids reliance on doc.pageItems ordering
//   (Illustrator inserts new items at index 0, making index-based
//   tracking unreliable across two conditions).
//
// Source folder: result/fig_stat_erp_cbpt/individual/

(function () {

    // ------------------------------------------------------------------
    // 1. Source folder
    // ------------------------------------------------------------------
    var folder = new Folder("C:/Users/kaito/workspace/exp1_EEG_analysis/result/fig_stat_erp_cbpt/individual");
    if (!folder.exists) {
        alert("Folder not found:\n" + folder.fullName);
        return;
    }

    // ------------------------------------------------------------------
    // 2. Active document check
    // ------------------------------------------------------------------
    if (app.documents.length === 0) {
        alert("No document is open. Please open an Illustrator document first.");
        return;
    }
    var doc = app.activeDocument;

    // ------------------------------------------------------------------
    // 3. RGB colour mode check
    // ------------------------------------------------------------------
    if (doc.documentColorSpace !== DocumentColorSpace.RGB) {
        if (confirm("Document is CMYK. Switch to RGB now?")) {
            app.executeMenuCommand("doc-color-rgb");
        } else {
            alert("Aborted. Switch to RGB manually and re-run.");
            return;
        }
    }

    // ------------------------------------------------------------------
    // 4. Layout constants (1 cm = 28.3465 pt)
    // ------------------------------------------------------------------
    var PT               = 28.3465;
    var ERP_W            = 10.0 * PT;  // ERP panel target width
    var TOPO_W           =  4.5 * PT;  // topomap width
    var TOPO_H           =  4.5 * PT;  // topomap height
    var GAP_COL          =  0.1 * PT;  // gap between ERP and topo within a row (reduced from 0.3)
    var GAP_ROW          =  0.5 * PT;  // gap between rows
    var GAP_LEG          =  0.3 * PT;  // gap between last row and legend
    var PAD              =  0.8 * PT;  // padding inside border box (left / right / top)
    var PAD_BOTTOM       =  0.4 * PT;  // bottom padding inside border box (separate to allow independent tuning)
    var LABEL_AREA       =  1.0 * PT;  // height reserved for condition label at box top
    var LABEL_MARGIN     =  4;         // offset of label text from box corner (pt)
    var GAP_COND         =  1.0 * PT;  // horizontal gap between the two condition boxes
    var OUTER_MARGIN     =  0.15 * PT; // outer margin added around all content to prevent border clipping
    var FONT_SIZE_LABEL  = 16;         // must match font_sz in stat_erp_cbpt.m

    var CONTENT_W = ERP_W + GAP_COL + TOPO_W;  // width of one row

    // ------------------------------------------------------------------
    // 5. Condition definitions
    // ------------------------------------------------------------------
    var conditions = [
        { letter: "A", title: "Go trials",    tags: ["go_pos_2", "go_pos_3", "go_neg_1"] },
        { letter: "B", title: "No-Go trials", tags: ["nogo_pos_2", "nogo_neg_2"]         }
    ];

    // ------------------------------------------------------------------
    // 6. Find a bold font (Arial family preferred)
    // ------------------------------------------------------------------
    var boldFont = null;
    try {
        var fonts = app.textFonts;
        for (var fi = 0; fi < fonts.length; fi++) {
            var f = fonts[fi];
            if (f.family === "Arial" && f.style === "Bold") { boldFont = f; break; }
        }
        if (!boldFont) { boldFont = app.textFonts.getByName("Arial-BoldMT"); }
    } catch (e) {
        try { boldFont = app.textFonts.getByName("ArialMT-Bold"); } catch (e2) {}
    }

    // ------------------------------------------------------------------
    // 7. Artboard origin
    // ------------------------------------------------------------------
    var ab = doc.artboards[0].artboardRect;  // [left, top, right, bottom]
    var x0 = ab[0] + PAD;
    var y0 = ab[1];  // artboard top; content starts just below

    // ------------------------------------------------------------------
    // 8. Place each condition panel
    // ------------------------------------------------------------------
    var nPlaced        = 0;
    var nMissing       = 0;
    // ERP panels are output at a dynamically computed size (tight bounding box
    // of the axes content).  Their width is approximately constant across panels
    // (x-axis labels are identical) but not guaranteed to be exactly ERP_W.
    // Scale each ERP panel to ERP_W so rows align precisely.
    var erpScaleFactor = 1.0;
    var scaleKnown     = false;

    // Bottom Y of the Go trials box (Illustrator coords: Y increases upward).
    // Saved after Go (ci=0) is processed so that the No-Go box (ci=1) can be
    // extended downward to match, regardless of how many rows No-Go has.
    var goBoxBottom = null;

    // Reusable geometricBounds variable
    var gb;

    for (var ci = 0; ci < conditions.length; ci++) {
        var cond = conditions[ci];
        var tags = cond.tags;

        // X origin for this condition.
        // Each box occupies approximately (CONTENT_W + 2*PAD); GAP_COND separates boxes.
        var condX = x0 + ci * (CONTENT_W + 2 * PAD + GAP_COND);

        // Content starts PAD below the artboard top.
        var curY = y0 - PAD;

        // Per-condition bounding box, updated inline after each item is positioned.
        // This is the only reliable approach because doc.pageItems is ordered
        // newest-first, making index-based tracking wrong for the second condition.
        var cMinX =  1e9, cMaxX = -1e9;
        var cMaxY = -1e9, cMinY =  1e9;

        // ---- Place ERP + topomap rows ----
        for (var i = 0; i < tags.length; i++) {
            var tag  = tags[i];
            var rowH = TOPO_H;  // fallback when ERP file is missing

            var erpPath = folder.fullName + "/" + tag + "_erp.pdf";
            var erpFile = new File(erpPath);

            if (erpFile.exists) {
                var erp  = doc.placedItems.add();
                erp.file = erpFile;
                // Scale to ERP_W — MATLAB's dynamic sizing means the PDF width
                // is the tight bounding box width (≈ constant but not exactly ERP_W).
                var sc   = (ERP_W / erp.width) * 100;
                erp.resize(sc, sc);
                rowH         = erp.height;
                erp.position = [condX, curY];
                if (!scaleKnown) { erpScaleFactor = sc / 100; scaleKnown = true; }
                // Update bounds inline
                gb = erp.geometricBounds;
                if (gb[0] < cMinX) { cMinX = gb[0]; }
                if (gb[1] > cMaxY) { cMaxY = gb[1]; }
                if (gb[2] > cMaxX) { cMaxX = gb[2]; }
                if (gb[3] < cMinY) { cMinY = gb[3]; }
                nPlaced++;
            } else {
                nMissing++;
            }

            var topoPath = folder.fullName + "/" + tag + "_topo.pdf";
            var topoFile = new File(topoPath);

            if (topoFile.exists) {
                var topo  = doc.placedItems.add();
                topo.file = topoFile;
                // Place at natural size (MATLAB outputs at exactly topo_cm x topo_cm)
                topo.position = [
                    condX + ERP_W + GAP_COL,
                    curY - (rowH - TOPO_H) / 2
                ];
                // Update bounds inline
                gb = topo.geometricBounds;
                if (gb[0] < cMinX) { cMinX = gb[0]; }
                if (gb[1] > cMaxY) { cMaxY = gb[1]; }
                if (gb[2] > cMaxX) { cMaxX = gb[2]; }
                if (gb[3] < cMinY) { cMinY = gb[3]; }
                nPlaced++;
            } else {
                nMissing++;
            }

            curY -= rowH + GAP_ROW;
        }

        // ---- Place legend ----
        // Cancel the trailing GAP_ROW from the last row, then apply GAP_LEG.
        curY += GAP_ROW;
        curY -= GAP_LEG;

        var legPath = folder.fullName + "/legend.pdf";
        var legFile = new File(legPath);

        if (legFile.exists) {
            var leg  = doc.placedItems.add();
            leg.file = legFile;
            // Scale by erpScaleFactor so legend text matches ERP panel font size
            leg.resize(erpScaleFactor * 100, erpScaleFactor * 100);
            // Right-align to content right edge
            leg.position = [condX + CONTENT_W - leg.width, curY];
            // Update bounds inline
            gb = leg.geometricBounds;
            if (gb[0] < cMinX) { cMinX = gb[0]; }
            if (gb[1] > cMaxY) { cMaxY = gb[1]; }
            if (gb[2] > cMaxX) { cMaxX = gb[2]; }
            if (gb[3] < cMinY) { cMinY = gb[3]; }
            nPlaced++;
        } else {
            nMissing++;
        }

        // ---- Draw border box ----
        // boxTop = content top + PAD + LABEL_AREA
        //   PAD:        standard inner padding above the topmost content item
        //   LABEL_AREA: extra space reserved for the condition label
        // boxBottom = content bottom - PAD, but extended to match Go's depth
        //   so that all condition boxes share the same height regardless of
        //   how many cluster rows each condition contains.
        //
        // LABEL_SIZE: apply erpScaleFactor so the condition label text appears
        //   at the same visual size as the scaled ERP panel axis labels.
        var LABEL_SIZE = FONT_SIZE_LABEL * erpScaleFactor;
        var boxTop    = cMaxY + PAD + LABEL_AREA;
        var boxLeft   = cMinX - PAD;
        var boxWidth  = (cMaxX - cMinX) + 2 * PAD;

        // Bottom edge Y of the border box (Illustrator: lower Y = further down).
        // PAD_BOTTOM (0.4 cm) is used instead of PAD (0.8 cm) to give a tighter
        // bottom margin below the legend while keeping left/right/top margins at PAD.
        var boxBottom = cMinY - PAD_BOTTOM;
        if (ci === 0) {
            goBoxBottom = boxBottom;           // save Go's bottom for later conditions
        } else if (goBoxBottom !== null && goBoxBottom < boxBottom) {
            boxBottom = goBoxBottom;           // extend No-Go box to match Go's depth
        }
        var boxHeight = boxTop - boxBottom;

        var borderRect = doc.pathItems.rectangle(
            boxTop, boxLeft, boxWidth, boxHeight
        );
        borderRect.stroked = true;
        borderRect.filled  = false;
        var strokeCol      = new RGBColor();
        strokeCol.red = 0; strokeCol.green = 0; strokeCol.blue = 0;
        borderRect.strokeColor = strokeCol;
        borderRect.strokeWidth = 2.0;

        // ---- Add panel letter (bold, upper-left inside LABEL_AREA zone) ----
        var letterItem = doc.textFrames.add();
        letterItem.contents = cond.letter;
        var letterAttr = letterItem.textRange.characterAttributes;
        letterAttr.size = LABEL_SIZE;
        if (boldFont) { letterAttr.textFont = boldFont; }
        letterItem.position = [
            boxLeft + LABEL_MARGIN,
            boxTop  - LABEL_MARGIN
        ];

        // ---- Add condition title (bold, horizontally centred in box) ----
        var titleItem = doc.textFrames.add();
        titleItem.contents = cond.title;
        var titleAttr = titleItem.textRange.characterAttributes;
        titleAttr.size = LABEL_SIZE;
        if (boldFont) { titleAttr.textFont = boldFont; }
        titleItem.position = [
            (cMinX + cMaxX) / 2 - titleItem.width / 2,
            boxTop  - LABEL_MARGIN
        ];
    }

    // ------------------------------------------------------------------
    // 9. Fit artboard to all content
    // ------------------------------------------------------------------
    var allPageItems = doc.pageItems;
    var abMinX =  1e9, abMaxX = -1e9;
    var abMaxY = -1e9, abMinY =  1e9;
    for (var k = 0; k < allPageItems.length; k++) {
        var gb2 = allPageItems[k].geometricBounds;
        if (gb2[0] < abMinX) { abMinX = gb2[0]; }
        if (gb2[1] > abMaxY) { abMaxY = gb2[1]; }
        if (gb2[2] > abMaxX) { abMaxX = gb2[2]; }
        if (gb2[3] < abMinY) { abMinY = gb2[3]; }
    }
    doc.artboards[0].artboardRect = [abMinX - OUTER_MARGIN, abMaxY + OUTER_MARGIN, abMaxX + OUTER_MARGIN, abMinY - OUTER_MARGIN];

    // ------------------------------------------------------------------
    // 10. Report
    // ------------------------------------------------------------------
    var msg = "Done. " + nPlaced + " items placed.";
    msg += "\nERP scale factor: " + erpScaleFactor.toFixed(3);
    msg += "\nLabel font size: " + (FONT_SIZE_LABEL * erpScaleFactor).toFixed(1) + " pt";
    if (nMissing > 0) {
        msg += "\n" + nMissing + " file(s) not found in:\n" + folder.fullName;
    }
    alert(msg);

})();
