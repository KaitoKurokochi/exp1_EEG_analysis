// arrange_erp.jsx
// Adobe Illustrator ExtendScript
//
// Place Go and No-Go ERP panels side-by-side in a single document.
// Each condition is placed in its own bordered box:
//
//   [Go condition box]  [GAP_COND]  [No-Go condition box]
//
// Inside each box:
//   [LABEL_AREA: "Go condition" / "No-Go condition" label (bold)]
//   [PAD]
//   [ERP row 1: waveform | topomap]
//   ...
//   [legend (right-aligned, placed at natural size)]
//   [PAD]
//
// No-scaling architecture:
//   MATLAB outputs all PDFs at the exact target size (ERP: 10 x 8 cm,
//   topomap: 4.5 x 4.5 cm).  This script places them at their natural
//   size (1:1) — no resize() calls anywhere.  Font sizes in Illustrator
//   (condition label) are set to FONT_SIZE_LABEL to match the MATLAB
//   font size used when generating the PDFs.
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
    // 1. Select source folder
    // ------------------------------------------------------------------
    var folder = Folder.selectDialog("Select the individual folder");
    if (!folder) { return; }

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
    var GAP_COL          =  0.3 * PT;  // gap between ERP and topo within a row
    var GAP_ROW          =  0.5 * PT;  // gap between rows
    var GAP_LEG          =  0.3 * PT;  // gap between last row and legend
    var PAD              =  0.8 * PT;  // padding inside border box (left/right/bottom)
    var LABEL_AREA       =  1.0 * PT;  // height reserved for condition label at box top
    var LABEL_MARGIN     =  4;         // offset of label text from box corner (pt)
    var GAP_COND         =  1.0 * PT;  // horizontal gap between the two condition boxes
    var FONT_SIZE_LABEL  = 16;         // must match font_sz in stat_erp_cbpt.m

    var CONTENT_W = ERP_W + GAP_COL + TOPO_W;  // width of one row

    // ------------------------------------------------------------------
    // 5. Condition definitions
    // ------------------------------------------------------------------
    var conditions = [
        { label: "Go condition",    tags: ["go_pos_2", "go_pos_3", "go_neg_1"] },
        { label: "No-Go condition", tags: ["nogo_pos_2", "nogo_neg_2"]         }
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
    var nPlaced  = 0;
    var nMissing = 0;

    // Bottom Y of the Go condition box (Illustrator coords: Y increases upward).
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
                // Place at natural size (MATLAB outputs at exactly ERP_W x erp_h_cm)
                rowH         = erp.height;
                erp.position = [condX, curY];
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
            // Place at natural size (MATLAB auto-sizes legend PDF to content)
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
        // LABEL_SIZE matches the MATLAB font size so condition label text
        //   appears at the same visual size as axis labels in the ERP panels.
        var LABEL_SIZE = FONT_SIZE_LABEL;
        var boxTop    = cMaxY + PAD + LABEL_AREA;
        var boxLeft   = cMinX - PAD;
        var boxWidth  = (cMaxX - cMinX) + 2 * PAD;

        // Bottom edge Y of the border box (Illustrator: lower Y = further down).
        var boxBottom = cMinY - PAD;
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
        borderRect.strokeWidth = 1.0;

        // ---- Add condition label (bold, upper-left inside LABEL_AREA zone) ----
        var textItem = doc.textFrames.add();
        textItem.contents = cond.label;
        var charAttr = textItem.textRange.characterAttributes;
        charAttr.size = LABEL_SIZE;
        if (boldFont) { charAttr.textFont = boldFont; }
        textItem.position = [
            boxLeft + LABEL_MARGIN,
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
    doc.artboards[0].artboardRect = [abMinX, abMaxY, abMaxX, abMinY];

    // ------------------------------------------------------------------
    // 10. Report
    // ------------------------------------------------------------------
    var msg = "Done. " + nPlaced + " items placed (no scaling — all PDFs at natural size).";
    msg += "\nLabel font size: " + FONT_SIZE_LABEL + " pt";
    if (nMissing > 0) {
        msg += "\n" + nMissing + " file(s) not found in:\n" + folder.fullName;
    }
    alert(msg);

})();
