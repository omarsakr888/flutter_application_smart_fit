# InBody Template Mapping — Visual Region Discovery Report

**Status:** Template discovery complete — extraction implementation must NOT begin until this document and the companion `templates/*.json` files are reviewed and approved.

**Reference scans:** `test_inbody_versions/`

| File | Model | Dimensions | Units | Subject |
|------|-------|------------|-------|---------|
| `inbody120.png` | InBody 120 | 722 × 1024 px | Metric (kg, cm, L) | Female, 51 yrs |
| `inbody270.png` | InBody 270 | 737 × 1024 px | Metric (kg, cm, L) | Female, 51 yrs |
| `inbody570.png` | InBody 570 | 796 × 1024 px | **Imperial** (lb, ft/in) | Female, 31 yrs |

**Design principle enforced by this document:**

```
Image → Detect Version → Load Template → Locate Known Regions → OCR Small Regions → Validate → JSON
```

NOT: `Image → Full-page OCR → Search all text → Guess fields`

---

## 1. Executive Summary — Why the OCR-First Approach Failed

The benchmark (0/31 fields correct) confirms the root cause: the pipeline treated InBody reports as **unstructured text**. Values like `30`, `203`, and `1` were pulled from **chart axes, scale markers, and history graphs** because no template constrained where OCR should look.

InBody reports are **semi-fixed templates**. Field locations are predictable once the version is known. Extraction must be **ROI-first, anchor-aligned, and version-specific**.

---

## 2. Cross-Version Layout Comparison

### 2.1 Shared structural elements (120 & 270 — “Legacy Metric Layout”)

Both 120 and 270 share the same **two-column skeleton**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [LOGO]                              [InBody XXX]              [branding]    │  ← HEADER (y: 0–10%)
│ ID | Height | Age | Gender | Test Date & Time                               │
├──────────────────────────────────────┬──────────────────────────────────────┤
│ LEFT COLUMN (~68% width)             │ RIGHT COLUMN (~32% width)            │
│                                      │                                      │
│ ■ Body Composition Analysis        │ ■ InBody Score                       │
│   (table: TBW→Weight)                │ ■ Weight Control                     │
│                                      │ ■ Obesity Evaluation (270 only)      │
│ ■ Muscle-Fat Analysis              │ ■ Waist-Hip Ratio                    │
│   (bar charts: Weight, SMM, BFM)   │ ■ Visceral Fat Level                 │
│                                      │ ■ Research Parameters                │
│ ■ Obesity Analysis                 │   (BMR, FFM, etc.)                   │
│   (bar charts: BMI, PBF)             │ ■ Calorie Expenditure (270 only)     │
│                                      │ ■ Impedance table                    │
│ ■ Segmental Lean │ Segmental Fat    │                                      │
│   (body figure diagrams)             │                                      │
│                                      │                                      │
│ ■ Body Composition History         │                                      │
│   (line graph + date table)          │                                      │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

### 2.2 InBody 570 — “Modern Imperial Layout” (structurally different)

570 uses a **wider aspect ratio** (0.777 vs ~0.71) and a **different Body Composition table orientation**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [LOGO]  ID | Height(ft/in) | Age | Gender | Date          [InBody570]     │
├──────────────────────────────────────┬──────────────────────────────────────┤
│ LEFT COLUMN                          │ RIGHT COLUMN                         │
│                                      │                                      │
│ ■ Body Composition Analysis        │ ■ Body Fat – Lean Body Mass Control  │
│   COLUMNS: Values | TBW | LBM | Wt   │ ■ Segmental Fat Analysis             │
│   (NOT the same row layout as 120!)  │ ■ Basal Metabolic Rate (standalone)  │
│                                      │ ■ Visceral Fat Level                 │
│ ■ Muscle-Fat Analysis (lb)         │ ■ Impedance (5/50/500 kHz)           │
│ ■ Obesity Analysis                 │ ■ QR Code                            │
│ ■ Segmental Lean Analysis (lb)     │                                      │
│ ■ ECW/TBW Analysis  ← 570 ONLY     │                                      │
│ ■ Body Composition History         │                                      │
│   (includes ECW/TBW column)          │                                      │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

---

## 3. Version Detection Anchors

| Anchor | InBody 120 | InBody 270 | InBody 570 |
|--------|------------|------------|------------|
| **Primary text tag** | `[InBody120]` top-right header | `[InBody 270]` top-center | `[InBody570]` top-right |
| **Secondary anchors** | `athletehome` logo block (top-right) | `www.inbody.com` | `SEE WHAT YOU'RE MADE OF` box |
| **Unique section** | Results Interpretation QR (no ECW) | Calorie Expenditure of Exercise table | **ECW/TBW Analysis** section |
| **Unit signal** | `(kg)`, `(cm)`, `(L)` | `(kg)`, `(cm)`, `(L)` | `(lb)`, `ft`, `in` |
| **Header height format** | `156.9cm` single field | `156.9cm` single field | `5 ft 05.0 in` composite |

**Detection order:** Primary tag → unique section presence → unit markers → aspect ratio fallback.

---

## 4. Section Map — Normalized Y-Bands

All coordinates are **fractions of image width (x) and height (y)**, origin top-left.
Measured from reference scans; implementation must **re-align using label anchors** (not blind crop).

### 4.1 InBody 120 (`722×1024`)

| Section | y_start | y_end | x_start | x_end | Anchor label |
|---------|---------|-------|---------|-------|--------------|
| `header` | 0.00 | 0.10 | 0.00 | 1.00 | `InBody` logo |
| `body_composition` | 0.10 | 0.26 | 0.02 | 0.68 | `Body Composition Analysis` |
| `muscle_fat` | 0.26 | 0.36 | 0.02 | 0.68 | `Muscle-Fat Analysis` |
| `obesity` | 0.36 | 0.46 | 0.02 | 0.68 | `Obesity Analysis` |
| `segmental_lean` | 0.46 | 0.62 | 0.02 | 0.36 | `Segmental Lean Analysis` |
| `segmental_fat` | 0.46 | 0.62 | 0.36 | 0.68 | `Segmental Fat Analysis` |
| `body_history` | 0.62 | 0.98 | 0.02 | 0.68 | `Body Composition History` |
| `inbody_score` | 0.10 | 0.18 | 0.68 | 0.98 | `InBody Score` |
| `weight_control` | 0.18 | 0.28 | 0.68 | 0.98 | `Weight Control` |
| `research_params` | 0.28 | 0.42 | 0.68 | 0.98 | `Research Parameters` |
| `impedance` | 0.88 | 0.98 | 0.68 | 0.98 | `Impedance` |

### 4.2 InBody 270 (`737×1024`)

| Section | y_start | y_end | x_start | x_end | Notes vs 120 |
|---------|---------|-------|---------|-------|--------------|
| `header` | 0.00 | 0.09 | 0.00 | 1.00 | `[InBody 270]` centered |
| `body_composition` | 0.09 | 0.24 | 0.02 | 0.66 | Slightly tighter vertical |
| `muscle_fat` | 0.24 | 0.34 | 0.02 | 0.66 | Same structure |
| `obesity` | 0.34 | 0.44 | 0.02 | 0.66 | Same structure |
| `segmental_lean` | 0.44 | 0.60 | 0.02 | 0.34 | Same structure |
| `segmental_fat` | 0.44 | 0.60 | 0.34 | 0.66 | Same structure |
| `body_history` | 0.60 | 0.98 | 0.02 | 0.66 | Same structure |
| `inbody_score` | 0.09 | 0.16 | 0.66 | 0.98 | Right column |
| `weight_control` | 0.16 | 0.24 | 0.66 | 0.98 | |
| `obesity_evaluation` | 0.24 | 0.30 | 0.66 | 0.98 | **270 only** |
| `waist_hip` | 0.30 | 0.34 | 0.66 | 0.98 | |
| `visceral_fat` | 0.34 | 0.38 | 0.66 | 0.98 | |
| `research_params` | 0.38 | 0.50 | 0.66 | 0.98 | BMR here |
| `calorie_expenditure` | 0.50 | 0.78 | 0.66 | 0.98 | **270 only** — DO NOT OCR for metrics |
| `impedance` | 0.78 | 0.88 | 0.66 | 0.98 | |

### 4.3 InBody 570 (`796×1024`)

| Section | y_start | y_end | x_start | x_end | Notes |
|---------|---------|-------|---------|-------|-------|
| `header` | 0.00 | 0.08 | 0.00 | 1.00 | Height in ft/in |
| `body_composition` | 0.08 | 0.22 | 0.02 | 0.62 | **Column-oriented table** |
| `muscle_fat` | 0.22 | 0.32 | 0.02 | 0.62 | Values in **lb** |
| `obesity` | 0.32 | 0.42 | 0.02 | 0.62 | BMI metric, PBF % |
| `segmental_lean` | 0.42 | 0.56 | 0.02 | 0.62 | Row labels: RA/LA/TR/RL/LL |
| `ecw_tbw` | 0.56 | 0.62 | 0.02 | 0.62 | **570 only** |
| `body_history` | 0.62 | 0.98 | 0.02 | 0.62 | Includes ECW/TBW history |
| `bf_lbm_control` | 0.08 | 0.16 | 0.62 | 0.98 | Right column |
| `segmental_fat` | 0.16 | 0.30 | 0.62 | 0.98 | |
| `bmr_standalone` | 0.30 | 0.36 | 0.62 | 0.98 | BMR **not** inside Research Params |
| `visceral_fat` | 0.36 | 0.42 | 0.62 | 0.98 | |
| `impedance` | 0.78 | 0.92 | 0.62 | 0.98 | 5/50/500 kHz |

---

## 5. Field-by-Field Visual Mapping — All 12 Target Metrics

Legend:
- **ROI** = normalized `{x, y, w, h}` crop region for OCR (small, field-specific)
- **Anchor** = label text used to dynamically align ROI if page scale shifts
- **Ref value** = ground truth from reference scan
- **Absent** = not present on this reference scan (do not impute from wrong region)

---

### 5.1 HEADER FIELDS (Age, Gender, Height)

Present on all three versions in the **top header band**, single horizontal row.

#### InBody 120

```
HEADER ROW (y ≈ 0.045 – 0.075)
┌────────┬──────────┬─────┬────────┬─────────────────────┐
│   ID   │  Height  │ Age │ Gender │  Test Date & Time   │
│ SM2008 │ 156.9cm  │ 51  │ Female │ 2012.05.04. 09:46   │
└────────┴──────────┴─────┴────────┴─────────────────────┘
  x≈.05    x≈.18      .30    .38         x≈.52–.70
```

| Field | Ref Value | Section | Anchor | ROI (x, y, w, h) | Unit | Format |
|-------|-----------|---------|--------|------------------|------|--------|
| **Age** | 51 | `header` | `Age` label | (0.28, 0.048, 0.06, 0.028) | yrs | integer |
| **Gender** | Female | `header` | `Gender` label | (0.36, 0.048, 0.10, 0.028) | word | Male/Female |
| **Height** | 156.9 | `header` | `Height` label | (0.16, 0.048, 0.10, 0.028) | cm | decimal |

#### InBody 270

Same header structure as 120; `[InBody 270]` replaces branding block.

| Field | Ref Value | ROI (x, y, w, h) | Notes |
|-------|-----------|------------------|-------|
| **Age** | 51 | (0.30, 0.042, 0.05, 0.025) | Slightly right-shifted vs 120 |
| **Gender** | Female | (0.38, 0.042, 0.10, 0.025) | |
| **Height** | 156.9 | (0.17, 0.042, 0.10, 0.025) | |

#### InBody 570

```
HEADER ROW (y ≈ 0.035 – 0.065)
┌────────┬────────────────┬─────┬────────┬──────────────────┐
│   ID   │     Height     │ Age │ Gender │ Test Date / Time │
│Jane Doe│ 5 ft 05.0 in   │ 31  │ Female │ 04.28.2021 07:13 │
└────────┴────────────────┴─────┴────────┴──────────────────┘
```

| Field | Ref Value | ROI (x, y, w, h) | Unit | Format |
|-------|-----------|------------------|------|--------|
| **Age** | 31 | (0.32, 0.038, 0.05, 0.025) | yrs | integer |
| **Gender** | Female | (0.40, 0.038, 0.10, 0.025) | word | Male/Female |
| **Height** | 5 ft 05.0 in | (0.15, 0.038, 0.14, 0.025) | ft/in | composite → convert to cm |

---

### 5.2 BODY COMPOSITION TABLE FIELDS (Weight, TBW, BFM)

#### InBody 120 & 270 — Vertical table (identical row order)

```
Body Composition Analysis
┌──────────────┬───────┬────────┬───────────────┐
│ Description  │ Field │  Unit  │ Value (range) │
├──────────────┼───────┼────────┼───────────────┤
│              │ TBW   │  (L)   │ 27.5 / 26.5   │  ← row 1
│              │Protein│  (kg)  │ 7.2           │
│              │Mineral│  (kg)  │ 2.63/2.64     │
│              │ BFM   │  (kg)  │ 21.8 / 22.8   │  ← row 4
│              │Weight │  (kg)  │ 59.1          │  ← row 5 (BOTTOM)
└──────────────┴───────┴────────┴───────────────┘
                              value col x ≈ 0.40–0.48
```

| Field | 120 Ref | 270 Ref | Anchor | ROI strategy |
|-------|---------|---------|--------|--------------|
| **TBW** | 27.5 L | 26.5 L | `Total Body Water` / `(L)` | Row 1, value cell: **120** (0.40, 0.155, 0.08, 0.022); **270** (0.40, 0.145, 0.08, 0.022) |
| **BFM** | 21.8 kg | 22.8 kg | `Body Fat Mass` / `(kg)` | Row 4: **120** (0.40, 0.205, 0.08, 0.022); **270** (0.40, 0.195, 0.08, 0.022) |
| **Weight** | 59.1 kg | 59.1 kg | `Weight` / `(kg)` | Row 5 (last): **120** (0.40, 0.225, 0.08, 0.022); **270** (0.40, 0.215, 0.08, 0.022) |

**Critical rule:** Value is in the **4th column**, NOT the normal-range column (col 5). OCR must crop col 4 only.

#### InBody 570 — Horizontal column table (DIFFERENT)

```
Body Composition Analysis
                Total Body Water   Lean Body Mass      Weight
Intracellular Water    39.9              —                —
Extracellular Water    24.3              —                —
Dry Lean Mass           —               23.8               —
Body Fat Mass           —                —               47.4
─────────────────────────────────────────────────────────────
TOTALS                 64.2              88.0            135.4
```

| Field | Ref Value | Anchor | ROI (x, y, w, h) | Notes |
|-------|-----------|--------|------------------|-------|
| **TBW** | 64.2 lb | `Total Body Water` column header + totals row | (0.28, 0.175, 0.10, 0.025) | Bottom of TBW column |
| **BFM** | 47.4 lb | `Body Fat Mass` row, Weight column | (0.52, 0.155, 0.10, 0.022) | Row NOT same as 120/270 |
| **Weight** | 135.4 lb | `Weight` column header + totals row | (0.52, 0.175, 0.10, 0.025) | Bottom-right of table |

---

### 5.3 MUSCLE-FAT ANALYSIS (SMM, Weight duplicate)

Bar chart section — value printed at **end of black bar**, right of chart.

```
Muscle-Fat Analysis
  Weight (kg/lb)     [====bar====] 59.1 / 135.4
  SMM (kg/lb)        [==bar==]     19.6 / 47.6
  Body Fat Mass      [====bar====] 21.8 / 47.4
```

| Field | Anchor | 120 ROI | 270 ROI | 570 ROI |
|-------|--------|---------|---------|---------|
| **SMM** | `SMM` / `Skeletal Muscle Mass` | (0.42, 0.295, 0.08, 0.022) | (0.42, 0.285, 0.08, 0.022) | (0.38, 0.265, 0.10, 0.022) |
| **Weight** (alt) | `Weight` in muscle-fat | (0.42, 0.270, 0.08, 0.022) | (0.42, 0.260, 0.08, 0.022) | (0.38, 0.240, 0.10, 0.022) |

**Primary Weight source:** Body Composition table row (more precise). Muscle-Fat bar value is **cross-validation only**.

---

### 5.4 OBESITY ANALYSIS (PBF)

```
Obesity Analysis
  BMI (kg/m²)        [==bar==]  24.0 / 22.5
  PBF (%)            [====bar==] 36.9 / 38.6 / 35.0
```

| Field | Anchor | 120 ROI | 270 ROI | 570 ROI |
|-------|--------|---------|---------|---------|
| **PBF** | `PBF` / `Percent Body Fat` | (0.42, 0.395, 0.08, 0.022) | (0.42, 0.385, 0.08, 0.022) | (0.38, 0.375, 0.10, 0.022) |

**Do NOT OCR:** BMI bar scale numbers (10, 15, 18.5, 25, 30, 35, 40, 45, 50) — these caused `30` false positives.

---

### 5.5 SEGMENTAL LEAN — Trunk FFM (Segmental FFM)

Trunk value is inside the **center body figure**, labeled `Trunk`.

```
Segmental Lean Analysis
     [RA]     [LA]
        [TRUNK]     ← target: trunk kg/lb value (large number)
     [RL]     [LL]
```

| Version | Ref Value | Anchor | ROI (x, y, w, h) |
|---------|-----------|--------|------------------|
| **120** | 17.7 kg | `Trunk` in lean figure | (0.14, 0.545, 0.12, 0.045) |
| **270** | 16.7 kg | `Trunk` in lean figure | (0.14, 0.525, 0.12, 0.045) |
| **570** | 39.6 lb | `Trunk` row in segmental table | (0.12, 0.485, 0.14, 0.025) |

570 uses a **row table** (RA/LA/TR/RL/LL), not a figure diagram — different ROI logic required.

---

### 5.6 RESEARCH PARAMETERS / BMR

| Version | Ref BMR | Location | Anchor | ROI (x, y, w, h) |
|---------|---------|----------|--------|------------------|
| **120** | 1176 kcal | Right col, Research Parameters | `Basal Metabolic Rate` | (0.72, 0.335, 0.18, 0.025) |
| **270** | 1154 kcal | Right col, Research Parameters | `Basal Metabolic Rate` | (0.68, 0.415, 0.22, 0.025) |
| **570** | 1231 kcal | Right col, **standalone section** | `Basal Metabolic Rate` | (0.66, 0.315, 0.22, 0.025) |

**Do NOT OCR from:** Calorie Expenditure table (270), Recommended calorie intake line, or history graph.

---

### 5.7 ECW/TBW — 570 ONLY

```
ECW/TBW Analysis
  ECW/TBW   [====bar====]  0.376
             Low    Normal    High
              0.360   0.390
```

| Version | Ref | Anchor | ROI (x, y, w, h) |
|---------|-----|--------|------------------|
| **120** | **Absent** | — | — |
| **270** | **Absent** | — | — |
| **570** | 0.376 | `ECW/TBW` | (0.22, 0.585, 0.10, 0.025) |

**Do NOT OCR:** Scale markers `0.360`, `0.390` — use value at bar end only.

---

### 5.8 Phase Angle — ABSENT on all three reference scans

| Version | Status on reference scan | Expected location (when present) |
|---------|--------------------------|----------------------------------|
| **120** | **Not printed** | N/A |
| **270** | **Not printed** | N/A |
| **570** | **Not printed** | Some 570+ reports: Research Parameters or Impedance section |

Template ROIs for phase angle are marked `"present": false` on all three templates. Implementation should return `null` with `validation_status: "absent_on_model"` rather than searching the full page.

---

## 6. Common vs Unique Regions Summary

| Region | 120 | 270 | 570 |
|--------|-----|-----|-----|
| Header (Age/Gender/Height) | ✓ metric | ✓ metric | ✓ **imperial height** |
| Body Composition table | ✓ vertical | ✓ vertical | ✓ **horizontal columns** |
| Muscle-Fat bars | ✓ | ✓ | ✓ (lb) |
| Obesity / PBF bars | ✓ | ✓ | ✓ |
| Segmental Lean trunk | ✓ figure | ✓ figure | ✓ **row table** |
| ECW/TBW section | ✗ | ✗ | ✓ |
| Research Parameters | ✓ | ✓ | ✗ (BMR standalone) |
| Calorie Expenditure | ✗ | ✓ (noise) | ✗ |
| Phase Angle | ✗ | ✗ | ✗ (on these scans) |
| Body History graph | ✓ (noise) | ✓ (noise) | ✓ (noise) |

**Regions that MUST be excluded from OCR** (chart noise sources):
- Body Composition History line graphs and date tables
- Calorie Expenditure of Exercise (270)
- Bar chart scale tick labels (Under/Normal/Over numbers)
- Impedance tables
- InBody Score circle graphic

---

## 7. Unit Differences

| Field | 120 / 270 | 570 | Conversion |
|-------|-----------|-----|------------|
| Height | cm | ft + in | `(ft×12 + in) × 2.54` |
| Weight, SMM, BFM, Trunk FFM | kg | lb | `× 0.453592` |
| TBW | L | lb (labeled lb on 570) | `÷ 2.20462` → L |
| BMR | kcal | kcal | none |
| PBF | % | % | none |
| ECW/TBW | — | ratio | none |

---

## 8. ROI-First Extraction Flow (Per Field)

Example — **Weight on InBody 270:**

```
1. Detect version     → "InBody270" via [InBody 270] tag
2. Load template      → templates/270_template.json
3. Locate section     → body_composition (anchor: "Body Composition Analysis")
4. Align ROI          → find "Weight" row label, offset to value column
5. Crop ROI           → ~(0.40, 0.215, 0.08, 0.022) of aligned section
6. OCR small crop     → EasyOCR on ~60×25 px patch only
7. Normalize          → "59 . 1" → 59.1
8. Validate           → range [30, 200] kg, cross-check with BFM+FFM
9. Return             → { value: 59.1, confidence, source_region: "body_composition" }
```

---

## 9. Template Files

Editable ROI definitions (no extraction code changes required):

```
smart_fit_backend/templates/
├── 120_template.json
├── 270_template.json
└── 570_template.json
```

Each template defines:
- Version detection anchors
- Section bounding boxes
- Per-field ROI + label anchor + unit + format
- Fields marked absent on this model
- Exclusion zones (history graph, calorie table, etc.)

---

## 10. Implementation Gate

| Gate | Status |
|------|--------|
| Reference scans inspected | ✅ |
| Cross-version comparison documented | ✅ |
| Per-field visual map complete | ✅ |
| Template JSON files created | ✅ |
| Exclusion zones identified | ✅ |
| ROI-first architecture specified | ✅ |
| **Extraction code implementation** | ⛔ **BLOCKED until template review** |

---

## 11. Next Step (After Approval)

1. Review and adjust ROI coordinates against scans at 100% zoom
2. Implement `TemplateLoader` + `AnchorAligner` (no full-page OCR)
3. Implement per-field ROI crop → OCR → validate pipeline
4. Re-run benchmark against ground truth in `test_ocr_accuracy.py`
