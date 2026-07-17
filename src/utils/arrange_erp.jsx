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
//   [legend (right-aligned, scaled to match ERP panels)]
//   [PAD]
//
// Font-size consistency:
//   ERP panels are scaled to ERP_W (10 cm).  The legend and condition
//   label are scaled by the same factor (erpScaleFactor) so all text
//   appears at the same visual size.
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
    var FONT_SIZE_MATLAB = 25;         // MATLAB FontSize used for ERP axes and legend

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
    var nPlaced        = 0;
    var nMissing       = 0;
    var erpScaleFactor = 1.0;
    var scaleKnown     = false;

    for (var ci = 0; ci < conditions.length; ci++) {
        var cond = conditions[ci];
        var tags = cond.tags;

        // X origin for this condition.
        // Each box occupies (CONTENT_W + 2*PAD); GAP_COND separates boxes.
        var condX = x0 + ci * (CONTENT_W + 2 * PAD + GAP_COND);

        // Content starts PAD below the artboard top.
        // LABEL_AREA is added to the box top after content bounds are known,
        // so no extra offset is needed here.
        var curY = y0 - PAD;

        // Record item count before placing this condition (for bounds tracking)
        var idxStart = doc.pageItems.length;

        // ---- Place ERP + topomap rows ----
        for (var i = 0; i < tags.length; i++) {
            var tag  = tags[i];
            var rowH = TOPO_H;  // fallback when ERP file is missing

            var erpPath = folder.fullName + "/" + tag + "_erp.pdf";
            var erpFile = new File(erpPath);

            if (erpFile.exists) {
                var erp  = doc.placedItems.add();
                erp.file = erpFile;
                var sc   = (ERP_W / erp.width) * 100;
                erp.resize(sc, sc);
                rowH         = erp.height;
                erp.position = [condX, curY];
                if (!scaleKnown) { erpScaleFactor = sc / 100; scaleKnown = true; }
                nPlaced++;
            } else {
                nMissing++;
            }

            var topoPath = folder.fullName + "/" + tag + "_topo.pdf";
            var topoFile = new File(topoPath);

            if (topoFile.exists) {
                var topo  = doc.placedItems.add();
                topo.file = topoFile;
                var tsc   = (TOPO_W / topo.width)  * 100;
                var tsy   = (TOPO_H / topo.height) * 100;
                topo.resize(tsc, tsy);
                topo.position = [
                    condX + ERP_W + GAP_COL,
                    curY - (rowH - TOPO_H) / 2
                ];
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
            leg.resize(erpScaleFactor * 100, erpScaleFactor * 100);
            // Right-align to content right edge
            leg.position = [condX + CONTENT_W - leg.width, curY];
            curY -= leg.height;
            nPlaced++;
        } else {
            nMissing++;
        }

        // ---- Compute bounding box of this condition's items only ----
        var allItems = doc.pageItems;
        var cMinX =  1e9, cMaxX = -1e9;
        var cMaxY = -1e9, cMinY =  1e9;
        for (var j = idxStart; j < allItems.length; j++) {
            var gb = allItems[j].geometricBounds;  // [left, top, right, bottom]
            if (gb[0] < cMinX) { cMinX = gb[0]; }
            if (gb[1] > cMaxY) { cMaxY = gb[1]; }
            if (gb[2] > cMaxX) { cMaxX = gb[2]; }
            if (gb[3] < cMinY) { cMinY = gb[3]; }
        }

        // ---- Draw border box ----
        // boxTop = content top + PAD + LABEL_AREA
        //   PAD:        standard inner padding above the topmost content item
        //   LABEL_AREA: extra space reserved for the condition label
        // boxBottom = content bottom - PAD
        var LABEL_SIZE = Math.round(FONT_SIZE_MATLAB * erpScaleFactor);
        var boxTop    = cMaxY + PAD + LABEL_AREA;
        var boxLeft   = cMinX - PAD;
        var boxWidth  = (cMaxX - cMinX) + 2 * PAD;
        var boxHeight = (cMaxY - cMinY) + 2 * PAD + LABEL_AREA;

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
    var msg = "Done. " + nPlaced + " items placed.";
    msg += "\nERP scale factor: " + erpScaleFactor.toFixed(3);
    msg += "\nLabel font size: " + Math.round(FONT_SIZE_MATLAB * erpScaleFactor) + " pt";
    if (nMissing > 0) {
        msg += "\n" + nMissing + " file(s) not found in:\n" + folder.fullName;
    }
    alert(msg);

})();
