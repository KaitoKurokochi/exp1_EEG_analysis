// arrange_erp.jsx
// Adobe Illustrator ExtendScript
//
// Place individual ERP + topomap PDFs + legend into the active document.
//   Layout : rows stacked top-to-bottom for the selected condition,
//            legend.pdf placed below the stack,
//            bordered box with condition label in the upper-left corner.
//
// Run separately for Go and No-Go conditions.
// Source folder: result/fig_stat_erp_cbpt/individual/

(function () {

    // ------------------------------------------------------------------
    // 1. Select condition
    // ------------------------------------------------------------------
    var isGo = confirm(
        "Condition?\n\nOK     = Go\nCancel = No-Go"
    );

    var TAGS = isGo
        ? ["go_pos_2", "go_pos_3", "go_neg_1"]
        : ["nogo_pos_2", "nogo_neg_2"];

    // ------------------------------------------------------------------
    // 2. Select source folder
    // ------------------------------------------------------------------
    var folder = Folder.selectDialog("Select the individual folder");
    if (!folder) { return; }

    // ------------------------------------------------------------------
    // 3. Active document check
    // ------------------------------------------------------------------
    if (app.documents.length === 0) {
        alert("No document is open. Please open an Illustrator document first.");
        return;
    }
    var doc = app.activeDocument;

    // ------------------------------------------------------------------
    // 4. RGB colour mode check
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
    // 5. Layout constants (1 cm = 28.3465 pt)
    // ------------------------------------------------------------------
    var PT            = 28.3465;
    var ERP_W         = 10.0 * PT;  // ERP panel target width (uniform scale)
    var TOPO_W        =  4.5 * PT;  // topomap target width
    var TOPO_H        =  4.5 * PT;  // topomap target height
    var GAP_COL       =  0.3 * PT;  // horizontal gap between ERP and topo
    var GAP_ROW       =  0.5 * PT;  // vertical gap between rows
    var GAP_LEG       =  0.8 * PT;  // gap between last row and legend
    var PAD           =  0.8 * PT;  // padding inside border box
    var LABEL_SIZE    = 14;         // condition label font size (pt)
    var LABEL_MARGIN  =  4;         // offset of label from box corner (pt)

    var CONTENT_W = ERP_W + GAP_COL + TOPO_W;  // total width of one row

    // ------------------------------------------------------------------
    // 6. Origin from current artboard
    // ------------------------------------------------------------------
    var ab   = doc.artboards[0].artboardRect;  // [left, top, right, bottom]
    var x0   = ab[0] + PAD;
    var curY = ab[1] - PAD;

    // ------------------------------------------------------------------
    // 7. Place ERP + topomap rows
    // ------------------------------------------------------------------
    var nPlaced  = 0;
    var nMissing = 0;

    for (var i = 0; i < TAGS.length; i++) {
        var tag  = TAGS[i];
        var rowH = TOPO_H;  // fallback row height when ERP file is missing

        // ---- ERP panel (left) ----
        var erpPath = folder.fullName + "/" + tag + "_erp.pdf";
        var erpFile = new File(erpPath);

        if (erpFile.exists) {
            var erp  = doc.placedItems.add();
            erp.file = erpFile;
            var sc   = (ERP_W / erp.width) * 100;  // uniform scale
            erp.resize(sc, sc);
            rowH         = erp.height;
            erp.position = [x0, curY];
            nPlaced++;
        } else {
            nMissing++;
        }

        // ---- Topomap (right, vertically centred on row) ----
        var topoPath = folder.fullName + "/" + tag + "_topo.pdf";
        var topoFile = new File(topoPath);

        if (topoFile.exists) {
            var topo  = doc.placedItems.add();
            topo.file = topoFile;
            var tsc   = (TOPO_W / topo.width)  * 100;
            var tsy   = (TOPO_H / topo.height) * 100;
            topo.resize(tsc, tsy);
            topo.position = [
                x0 + ERP_W + GAP_COL,
                curY - (rowH - TOPO_H) / 2
            ];
            nPlaced++;
        } else {
            nMissing++;
        }

        curY -= rowH + GAP_ROW;
    }

    // ------------------------------------------------------------------
    // 8. Place legend below the stack
    // ------------------------------------------------------------------
    curY -= GAP_LEG;

    var legPath = folder.fullName + "/legend.pdf";
    var legFile = new File(legPath);

    if (legFile.exists) {
        var leg  = doc.placedItems.add();
        leg.file = legFile;
        // Place at natural PDF size (no scaling).
        // Right-align: position left edge so right edge meets content right edge.
        leg.position = [x0 + CONTENT_W - leg.width, curY];
        curY -= leg.height;
        nPlaced++;
    } else {
        nMissing++;
    }

    curY -= PAD;

    // ------------------------------------------------------------------
    // 9. Compute content bounding box
    // ------------------------------------------------------------------
    var items = doc.pageItems;
    var minX =  1e9, maxX = -1e9;
    var maxY = -1e9, minY =  1e9;
    for (var j = 0; j < items.length; j++) {
        var gb = items[j].geometricBounds;  // [left, top, right, bottom]
        if (gb[0] < minX) { minX = gb[0]; }
        if (gb[1] > maxY) { maxY = gb[1]; }
        if (gb[2] > maxX) { maxX = gb[2]; }
        if (gb[3] < minY) { minY = gb[3]; }
    }

    // ------------------------------------------------------------------
    // 10. Draw border rectangle around all content
    // ------------------------------------------------------------------
    var boxTop    = maxY + PAD;
    var boxLeft   = minX - PAD;
    var boxWidth  = (maxX - minX) + 2 * PAD;
    var boxHeight = (maxY - minY) + 2 * PAD;

    var borderRect = doc.pathItems.rectangle(
        boxTop, boxLeft, boxWidth, boxHeight
    );
    borderRect.stroked = true;
    borderRect.filled  = false;
    var strokeColor    = new RGBColor();
    strokeColor.red    = 0;
    strokeColor.green  = 0;
    strokeColor.blue   = 0;
    borderRect.strokeColor = strokeColor;
    borderRect.strokeWidth = 1.0;

    // ------------------------------------------------------------------
    // 11. Add condition label in upper-left corner
    // ------------------------------------------------------------------
    var condLabel = isGo ? "Go" : "No-Go";
    var textItem  = doc.textFrames.add();
    textItem.contents = condLabel;
    var charAttr  = textItem.textRange.characterAttributes;
    charAttr.size = LABEL_SIZE;
    try { charAttr.textFont = app.textFonts.getByName("ArialMT-Bold"); } catch (e) {}
    // position: just inside upper-left corner of the border box
    textItem.position = [
        boxLeft + LABEL_MARGIN,
        boxTop  - LABEL_MARGIN
    ];

    // ------------------------------------------------------------------
    // 12. Fit artboard to all content including border and label
    // ------------------------------------------------------------------
    var allItems = doc.pageItems;
    var abMinX =  1e9, abMaxX = -1e9;
    var abMaxY = -1e9, abMinY =  1e9;
    for (var k = 0; k < allItems.length; k++) {
        var gb2 = allItems[k].geometricBounds;
        if (gb2[0] < abMinX) { abMinX = gb2[0]; }
        if (gb2[1] > abMaxY) { abMaxY = gb2[1]; }
        if (gb2[2] > abMaxX) { abMaxX = gb2[2]; }
        if (gb2[3] < abMinY) { abMinY = gb2[3]; }
    }
    doc.artboards[0].artboardRect = [abMinX, abMaxY, abMaxX, abMinY];

    // ------------------------------------------------------------------
    // 13. Report
    // ------------------------------------------------------------------
    var cond = isGo ? "Go" : "No-Go";
    var msg  = cond + " condition: " + nPlaced + " items placed.";
    if (nMissing > 0) {
        msg += "\n" + nMissing + " file(s) not found in:\n" + folder.fullName;
    }
    alert(msg);

})();
