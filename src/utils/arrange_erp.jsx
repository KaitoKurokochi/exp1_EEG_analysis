// arrange_erp.jsx
// Adobe Illustrator ExtendScript
//
// Place individual ERP + topomap PDFs into the active document.
//   Layout : [ERP panel]  [topomap]   <- one row per cluster
//            rows stacked top-to-bottom for the selected condition
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
    var PT      = 28.3465;
    var ERP_W   = 10.0 * PT;  // ERP panel target width  (uniform scale)
    var TOPO_W  =  4.5 * PT;  // topomap target width
    var TOPO_H  =  4.5 * PT;  // topomap target height
    var GAP_COL =  0.3 * PT;  // horizontal gap between ERP and topo
    var GAP_ROW =  0.3 * PT;  // vertical gap between rows

    // ------------------------------------------------------------------
    // 6. Origin from current artboard
    // ------------------------------------------------------------------
    var ab   = doc.artboards[0].artboardRect;  // [left, top, right, bottom]
    var x0   = ab[0];
    var curY = ab[1];  // top of artboard; decreases as we go down

    // ------------------------------------------------------------------
    // 7. Place items row by row
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
    // 8. Fit artboard to all placed content
    // ------------------------------------------------------------------
    var items = doc.pageItems;
    if (items.length > 0) {
        var minX =  1e9, maxX = -1e9;
        var maxY = -1e9, minY =  1e9;
        for (var j = 0; j < items.length; j++) {
            var gb = items[j].geometricBounds;  // [left, top, right, bottom]
            if (gb[0] < minX) { minX = gb[0]; }
            if (gb[1] > maxY) { maxY = gb[1]; }
            if (gb[2] > maxX) { maxX = gb[2]; }
            if (gb[3] < minY) { minY = gb[3]; }
        }
        doc.artboards[0].artboardRect = [minX, maxY, maxX, minY];
    }

    // ------------------------------------------------------------------
    // 9. Report
    // ------------------------------------------------------------------
    var cond = isGo ? "Go" : "No-Go";
    var msg  = cond + " condition: " + nPlaced + " items placed.";
    if (nMissing > 0) {
        msg += "\n" + nMissing + " file(s) not found in:\n" + folder.fullName;
    }
    alert(msg);

})();
