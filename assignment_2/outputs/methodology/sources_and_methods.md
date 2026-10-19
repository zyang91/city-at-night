# Sources and Methods: Governance and Land Use Brief (Phase 2)

CPLN 6890 The City at Night · Rittenhouse Square · prepared 18 October 2026

## 0. Starting point and reuse

The repository held raw governance and zoning layers in `data/` and one clipping script (`data-precessing.R`). It held **no saved Phase 1 outputs**: no summaries, permission matrix, memo or figures. To avoid repeating GIS work in later steps:

- `scripts/01_governance_zoning.R` re-implements the same clips as `data-precessing.R` (that script is left unchanged). It works in EPSG:2272 (PA State Plane South, US ft) with `st_make_valid()`, because the overlay layer has invalid geometries that make `st_intersection()` fail. It writes the clipped layers to `data/derived/*.gpkg`, and later scripts read those files instead of re-clipping.
- The teammate's licence extracts (`data/bl_ritt.gpkg`, `data/plcb_ritt.gpkg`) were already clipped to the study area. That was checked: 0 of 575 and 0 of 46 points fall outside it. The clip was reused, not redone.

Run order, from `assignment_2/`:

1. `Rscript scripts/01_governance_zoning.R`
2. `Rscript scripts/02_licensing_zoning.R`
3. `Rscript scripts/03_figures.R`
4. `sh scripts/04_render_memo.sh`

## 1. Data sources

| Data | File | Source / date |
|---|---|---|
| Study area | `studyAreas2026.geojson` (Name = RITTENHOUSE SQUARE) | Course |
| Zoning base districts, overlays, RCOs | `Zoning_BaseDistricts.geojson`, `Zoning_Overlays.geojson`, `Zoning_RCO.geojson` | PCPC via OpenDataPhilly |
| Council districts (2024), police districts, commercial corridors, special vending districts | `Council_Districts_2024.geojson`, `Boundaries_District.geojson`, `Commercial_Corridors.geojson`, `Vending_Special_Districts.geojson` | OpenDataPhilly |
| BIDs | `business_improvement_districts.shp` | Commerce Dept. |
| City business licences | `bl_ritt.gpkg` (575 records, 46 fields) | L&I business licences; teammate extract (file dated 15 Oct 2026) |
| PLCB liquor licences | `plcb_ritt.gpkg` (46 records) | PA Liquor Control Board licence search; teammate extract, geocoded (lat/lon) |
| Zoning permits and ZBA appeals | `data/derived/carto_zoning_permits_ritt.csv` (454), `carto_appeals_ritt.csv` (305) | L&I `permits` and `appeals` tables, public Carto SQL API (`phl.carto.com`), the data behind atlas.phila.gov. Spatial query: study area plus 50 ft. Retrieved 18 Oct 2026. Coverage ≈ 2007 onward. |
| Philadelphia Zoning Code | §14-502 (/CTR), §14-529 (/VDO), §14-601(7) (use definitions), §14-602 Tables 14-602-1, -2, -4, Table 14-502-2 | codelibrary.amlegal.com, "latest", read 18 Oct 2026 |

**Unit of record.** In the City licence data, one record is **one licence** at an address: a business can hold several (food, sidewalk café, streetery, special assembly). In the PLCB data, one record is **one liquor licence** for one premises and licensee. Neither file is a list of establishments, so establishments were built by matching (§3).

## 2. Licence status filters ("current and relevant")

Reference date: **18 Oct 2026**. Audit table: `outputs/analysis/licence_record_audit.csv`.

- **City licences:** included if `licensestatus = Active`, `inactivedate` is empty, and `expirationdate` ≥ 18 Oct 2026. One relevant licence (La Fontana Della Citta, food 30+ seats, expired 14 Oct 2026) is "Active" but past its expiration date. It is excluded from the current count; the establishment stays in because its PLCB licence is active.
  - *Primary (operating) types:* Food Preparing and Serving (30+ SEATS) (41; 40 current); Food Preparing and Serving (21); Food Establishment, Outdoor (1); Special Assembly Occupancy (1) → **63 current**.
  - *Ancillary types* (outdoor seating attached to an establishment): Sidewalk Cafe (19), Streetery (3) → **22**. One sidewalk-café licence (Square East Restaurant, 1003152) is attached to no establishment with a current primary licence; its PLCB licence is in safekeeping. It is counted as a licence record but has no establishment.
  - *Excluded as not nighttime establishments:* rental, dumpster, high-rise, parking, hazardous materials, handbill, precious metals, vacant property, limited lodging (2; residential short-term rental), small games of chance (1; an organisation's permit), and retail food establishments (6; grocery/pharmacy/market retail sales, a different zoning use category).
- **PLCB licences:** included if `Status = Active` and the type is a retail on-premises licence: Restaurant (Liquor) 34, Hotel (Liquor) 4, Catering Club (Liquor) 1 → **39**. Excluded: Restaurant in *Safekeeping* (4; licence held but not operating), *Pending* (2; not yet issued), Importer (1; not an on-premises licence). All active PLCB licences expire 31 Oct 2026 (normal renewal cycle).
- **Total relevant current licence records: 124** (39 PLCB + 63 City primary + 22 City ancillary).

Other checks: 0 duplicate City licence numbers, 0 duplicate PLCB licence numbers, 0 missing geometries. City licence geometry matches its `geocode_x/y` to within 0.2 ft.

## 3. Establishment matching (licences → establishments)

The crosswalk is a hand-reviewed table inside `02_licensing_zoning.R` (columns: establishment ID, PLCB licence(s), City licence(s), confidence, note). The script checks that every included licence maps to exactly one establishment.

- **Candidate generation:** for each PLCB licence, City food/assembly licences within 130 ft were listed with distance and names.
- **Match rule:** a match needs (a) agreement between the licensee/legal/trade name in the two files, or between the PLCB premises owner and the City licensee, and (b) the same address, an overlapping address range, or the same corner or through-lot building.
  - *High:* name and address agree (e.g., Sawan's Bistro).
  - *Medium:* entity names or addresses differ but other evidence links them: Warwick Hotel (AP RAD VENTURE LP = AP/RAD VENTURE LP; 220 S 17th = 1701-15 Locust), The Rittenhouse (Hersha / HHLP), Dear Daphne (1930 Sansom vs 1909 Walnut, through-lot), Marathon on the Square (same address, different LP names).
  - *Unmatched:* no City licence found, kept as separate establishments: VIP 220 LLC, 1920 Philly LLC, Catholic Philopatrian Literary Institute, The Prime Rib.
- **Result:** 39 PLCB licences → 39 establishments; 35 matched to City licences (31 High, 4 Medium) and 4 unmatched. 24 further establishments hold City food-service licences only. **Total 63 identifiable establishments.**
- **Unresolved matching:** 1920 Philly LLC (PLCB) vs Veda Inc (City, 1920-22 Chestnut) may be one premises; kept separate (count could be 62). DCEP LLC holds two City food licences (108 and 110 S 18th), treated as one premises. Sushi Awarsei (1730-32 Chestnut) may operate inside Di Bruno Bros. Goldie, Barry's Bootcamp and Cavanaugh's share 112 S 19th. The establishment count therefore carries about ±2 uncertainty.
- **Representative location:** the City licence geocode (City address system) when available, otherwise the PLCB point. The PLCB point's district is kept as a second opinion (`plcb_point_district`).

## 4. Spatial join to zoning

- Point-in-polygon join to the clipped base districts (EPSG:2272): **0 duplicate matches**. No points fall in street right-of-way; a nearest-district fallback exists in the code but was not needed.
- `dist_to_other_district_ft` is the distance to the nearest *different* base district. Points **within 20 ft** of a boundary (rough geocode error) are evaluated in both districts. If the status differs, the case is **UNDETERMINED** (5 cases, all on CMX-2/RM-4 boundaries).
- Overlays are read at the point. Applicability of the Chestnut & Walnut Street Area is tested two ways: the overlay polygon and whether any linked address is on Chestnut or Walnut Street. The Code defines the area as "lots fronting on Chestnut or Walnut Street" (§14-502(2)(b)(.8)). If the two tests disagree and change the status, the case is **UNDETERMINED**. AKA Rittenhouse is the exception: its ambiguity was resolved by a ZBA record (§6).
- PLCB-point check: the Parc PLCB point (227 S 18th) falls in RMX-3, its City point (Chancellor St) in CMX-5. A sit-down restaurant is by right in both, so the status is unaffected.

## 5. License-to-zoning-use classification rules

Licence categories are **not** zoning uses. Candidate Code uses were assigned from licence evidence and the §14-601(7) definitions:

| Licence evidence | Candidate zoning use(s) | Basis |
|---|---|---|
| PLCB Restaurant (Liquor) | Sit-Down Restaurant (probable) | A PA restaurant licence requires food service with seating for at least 30. That exceeds the 20-seat cap for a Prepared Food Shop and the "<4 seats" take-out test. Take-out by counter service and disposable ware is possible but unlikely. |
| PLCB Hotel (Liquor) | Visitor Accommodations + Sit-Down Restaurant (strictest governs) | Hotels here also hold City food licences for public restaurants. A 2012 ZBA case at 135 S 18th treated a hotel restaurant as a separate use. |
| PLCB Catering Club | Fraternal Organization **or** Event Assembly Facility | Private club; the use is uncertain, but both have the same status at its location. |
| City food licence 30+ seats, no liquor | Take-Out **or** Sit-Down Restaurant | 30+ seats rules out a Prepared Food Shop (≤20 seats). |
| City food licence <30 seats | Prepared Food Shop **or** Take-Out **or** Sit-Down | The licence cannot tell them apart. |
| Special Assembly Occupancy (Lucy's) | Sit-Down Restaurant + Assembly & Entertainment | Confirmed by permit ZP-2022-010220. |
| Food licence in a fitness or grocery business | Accessory use / retail **or** eating & drinking | Barry's Bootcamp, Maxx's Produce. |

"Nightclubs and Public Entertainment Venue" was **not** assigned to any liquor licence by default. That use requires ≥50 people gathering *primarily* for entertainment (§14-601(7)(c)(.2)), and the licence data do not show this.

**Status rule.** For each candidate use: status = the base-district cell (Tables 14-602-1/-2/-4), made stricter by the overlay (Table 14-502-2; "N" overrides "S", "S" overrides "Y"). Uses present together ("+") take the strictest status. For alternatives ("|"): if all candidates give the same status, that status is reported ("use uncertain, status robust"); otherwise the case is **UNDETERMINED**.

**Classes:** BY-RIGHT (Y) · SPECIAL APPROVAL REQUIRED (S, special exception under §14-303(7)) · NOT PERMITTED BY RIGHT (N: prohibited or unlisted in the district, so relief such as a variance or nonconforming status would be needed) · UNDETERMINED.

### Code provisions applied (verified 18 Oct 2026)

- **Table 14-602-2 (commercial):** Sit-Down Restaurant Y in CMX-2…5. Take-Out S in CMX-2, Y in CMX-3/4/5. Prepared Food Shop Y. Nightclubs & Public Entertainment Venue S in CMX-2/3, Y in CMX-4/5. Assembly & Entertainment and Event Assembly Facility S in CMX-2/3, Y in CMX-4/5. Visitor Accommodations N in CMX-2, Y in CMX-3/4/5.
- **Table 14-602-1 (residential):** in RM-1 and RM-4, eating & drinking and visitor accommodations are N. In RMX-3 they are Y, subject to note [5]: retail and commercial service ≤25% of GFA. Assembly & entertainment is not listed for residential districts, so it is prohibited ("uses not listed are prohibited").
- **Table 14-602-4 (SP-PO-A):** eating & drinking Y[5], only co-located with and smaller than a park use. Assembly & entertainment and visitor accommodations N.
- **Table 14-502-2 (/CTR supplemental use controls), Chestnut and Walnut Street Area, West:** eating & drinking establishments S[4] (note [4]: does not apply to residentially zoned lots); Take-Out Restaurant S. The Center City Commercial District Control Area and the Rittenhouse Square Residential Area have no eating/drinking controls. /VDO (§14-529) and /NIS (§14-540) contain no nighttime-use controls.
- City records confirm how this is applied. Lucy's 2023 refusal reads: "THE PROPOSED, SIT-DOWN RESTAURANT, IS A SPECIAL EXCEPTION UNDER CHESTNUT AND WALNUT STREET, WEST."

## 6. Authorization evidence (approvals ≠ by-right)

Permits and appeals were matched to establishments by OPA account number or by street plus an overlapping house-number range of the same parity. Records were then filtered to eating, drinking, assembly and hotel scopes (`outputs/analysis/zoning_approval_records_matched.csv`). Automatic matches over-include, for example sign permits that mention "restaurant". **Every non-by-right or undetermined case (34) was therefore read and reviewed by hand.** The review table (`mr`) in `02_licensing_zoning.R` records an evidence level:

- **Verified (6):** the record's scope matches the establishment's use and premises. Lucy's (ZP-2022-010220, 2023); Smallville (ZP-2023-006485, 2024); Walnut Garden (ZP-2023-010662, temporary to 31 Mar 2028); Gran Caffe L'Aquila (21023, 2013; 22575, 2014); Dear Daphne (ZP-2023-001038, 2023 unity of use); AKA Rittenhouse restaurant (19302, 2012).
- **Partial (7):** an eating/drinking approval exists at the address, but the link to the current tenant is unconfirmed: Kfar, Huayu, Pietro's, 1715 on Rittenhouse (a 2026 Visitor Accommodations permit only), Zacs Halal, Red Machi 209, Vibrant Coffee.
- **None found (9):** The Rittenhouse hotel, Di Bruno Bros, 1920 Philly LLC, Marathon on the Square, Sushi Awarsei, Essex Squeeze, La Colombe, Veda, Luna BYOB.

Limits: the Carto data start around 2007, so approvals or nonconforming status from before then cannot be seen. Pre-2016 ZBA records (`RB_ZBA`) carry a decision code (e.g., GRANTED/PROV) but not always a full scope. Records are address-level. Use-registration permits for by-right uses were **not** checked. None of this is a finding of non-compliance.

## 7. Results reconciliation

- Licences 124 → establishments 63 (counts kept separate; see §2–3).
- Classes (denominator: 63 establishments): BY-RIGHT 29 (46%), SPECIAL APPROVAL 16 (25%), NOT PERMITTED BY RIGHT 6 (10%), UNDETERMINED 12 (19%).
- Liquor-licensed subset (39): 21 / 10 / 3 / 5.
- By district (establishments): CMX-5 31, CMX-4 14, CMX-2 9, RM-4 5, RMX-3 2, CMX-3 1, RM-1 1.
- All 16 special-approval cases lie in the Chestnut & Walnut overlay polygon. All 6 not-by-right cases are in RM-4 (5) or RM-1 (1).
- Verification status: 25 verified by rule; 4 by right but flagged for licence-match confidence (Warwick Hotel, VIP 220, Catholic Philopatrian, The Prime Rib); 6 not by right with an approval verified; 7 address-level only; 9 none found; 12 unverified (ambiguous).

These totals are produced by the script from `licensing_zoning_comparison.csv` and match the memo and Figure 3.

## 8. Unresolved cases (need Atlas / L&I follow-up)

- **Overlay frontage unknown:** 112 S 19th (Cavanaugh's, Goldie, Barry's Bootcamp), Rouge 98 (201/205 S 18th), Tomboi (1705 Chancellor licence vs 1704 Walnut, where a 2021 permit is for apparel retail).
- **Within 20 ft of a CMX-2/RM-4 boundary:** ACT3, La Fontana Della Citta, Maxx's Produce, Malai, Bakeshop on 20th.
- **Use type decides status (CMX-2 take-out = S):** Starbucks and Blank Street at 1801 Spruce.
- **No approval found** for non-by-right uses: see §6.
- **Licence matching uncertainties:** see §3.

## 9. Outputs

`outputs/analysis/`: `governance_summary.csv`, `zoning_summary.csv`, `zoning_overlay_summary.csv`, `zoning_permission_matrix.csv`, `licensing_zoning_comparison.csv` (one row per establishment, 63 rows), and helpers `licence_record_audit.csv` and `zoning_approval_records_matched.csv`.

`outputs/figures/`: `zoning_map.png`, `zoning_licensed_businesses.png` (Fig. 1; official City zoning colours from the Zoning_BaseDistricts ArcGIS service renderer; points show zoning status only), `permission_matrix.png` (Fig. 2), `licensing_zoning_summary.png` (Fig. 3; in the files only, because the memo uses the equivalent table).

`outputs/memo/`: `governance_land_use_memo.md` (editable source), `governance_land_use_memo.pdf` (2 pages).

No statistical tests were run. The analysis is descriptive and makes no causal claims.
