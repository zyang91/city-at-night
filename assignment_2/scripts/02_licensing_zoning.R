# 02_licensing_zoning.R
# Licensing–zoning integration for the Rittenhouse Square study area.
# Inputs : teammate's pre-clipped licence extracts (data/bl_ritt.gpkg,
#          data/plcb_ritt.gpkg), clipped zoning from 01_governance_zoning.R,
#          City zoning permits / ZBA appeals pulled from phl.carto.com
#          (data/derived/carto_*.csv, retrieved 2026-10-18).
# Output : outputs/analysis/licensing_zoning_comparison.csv (+ helpers)
# Run from assignment_2/ after 01_governance_zoning.R.

suppressMessages({library(sf); library(tidyverse)})
sf_use_s2(FALSE)
P <- 2272
AS_OF <- as.POSIXct("2026-10-18", tz = "UTC")
CODE_2012 <- as.Date("2012-08-22")   # effective date of the current Zoning Code

sa    <- st_read("data/derived/study_area.gpkg", quiet = TRUE)
zbase <- st_read("data/derived/zoning_base_clip.gpkg", quiet = TRUE)
zover <- st_read("data/derived/zoning_overlay_clip.gpkg", quiet = TRUE)
cw    <- zover |> filter(grepl("Chestnut and Walnut Street Area", overlay_name)) |> st_union()

# ---- 1. Licence records ----------------------------------------------------
bl_all <- st_read("data/bl_ritt.gpkg", quiet = TRUE) |> st_transform(P)
pl_all <- st_read("data/plcb_ritt.gpkg", quiet = TRUE) |> st_transform(P)

bl_types_primary   <- c("Food Preparing and Serving (30+ SEATS)", "Food Preparing and Serving",
                        "Food Establishment, Outdoor", "Special Assembly Occupancy")
bl_types_ancillary <- c("Sidewalk Cafe", "Streetery License")

bl <- bl_all |>
  mutate(current = licensestatus == "Active" & is.na(inactivedate) &
           (is.na(expirationdate) | expirationdate >= AS_OF),
         role = case_when(licensetype %in% bl_types_primary ~ "primary",
                          licensetype %in% bl_types_ancillary ~ "ancillary",
                          TRUE ~ "not relevant"))
pl <- pl_all |>
  mutate(retail_type = License.Type %in% c("Restaurant (Liquor)", "Hotel (Liquor)", "Catering Club (Liquor)"),
         current = Status == "Active",
         role = if_else(retail_type, "primary", "not relevant"))

lic_audit <- bind_rows(
  bl |> st_drop_geometry() |> count(source = "City business licence", licence_type = licensetype,
                                    status = licensestatus, current, role),
  pl |> st_drop_geometry() |> count(source = "PLCB liquor licence", licence_type = License.Type,
                                    status = Status, current, role)) |>
  mutate(included = current & role != "not relevant")
write_csv(lic_audit, "outputs/analysis/licence_record_audit.csv")

# Data-quality checks (reported in methodology)
qc <- list(
  bl_dup_licensenum = sum(duplicated(bl_all$licensenum)),
  pl_dup_licence    = sum(duplicated(pl_all$License.Number)),
  bl_empty_geom     = sum(st_is_empty(bl_all)),
  pl_empty_geom     = sum(st_is_empty(pl_all)),
  bl_outside_sa     = sum(lengths(st_intersects(bl_all, sa)) == 0),
  pl_outside_sa     = sum(lengths(st_intersects(pl_all, sa)) == 0),
  bl_active_but_expired = sum(bl_all$licensestatus == "Active" &
                                !is.na(bl_all$expirationdate) & bl_all$expirationdate < AS_OF))
print(qc)

# ---- 2. Establishment crosswalk (hand-reviewed; see methodology) ---------
# One row per identifiable establishment. Licence numbers separated by ";".
# Matching basis: licensee/business-name agreement plus address or
# same-building proximity (<130 ft). Confidence: High / Medium / Unmatched.
xw <- tribble(
  ~est_id, ~establishment, ~plcb, ~bl, ~match_confidence, ~match_note, ~candidates,
  "E01","Parc","R13585","450032;441275","High","Same licensee (PARC RESTAURANT PARTNERS LP); corner building 227 S 18th / 1708-16 Chancellor","SD",
  "E02","Warwick Hotel (incl. Tavern 17, coffee bar)","H6433","209166;209167","Medium","PLCB licensee AP RAD VENTURE LP = BL legal name AP/RAD VENTURE LP; 220 S 17th and 1701-15 Locust are one corner building","VA+SD",
  "E03","VIP 220 LLC (in Warwick building)","R1920","","Unmatched","No City food licence in extract; premises owner AP RAD VENTURE LP; trade name not given","SD",
  "E04","The Rittenhouse (hotel)","H6307","0987892;0987948","Medium","PLCB licensee Hersha Hospitality; BL HHLP Rittenhouse Associates (The Rittenhouse); 202-10 W Rittenhouse Sq","VA+SD",
  "E05","Sofitel Philadelphia","H57729","0986697","High","BL business name cites Sofitel; owner OC Sansom Project Owner LLC in both","VA+SD",
  "E06","Sawan's Bistro","R2769","209469;320091","High","Same name and address","SD",
  "E07","SY Choi Inc (1933 Spruce)","R4229","906689","High","Same name and address","SD",
  "E08","Cavanaugh's Rittenhouse","R4439","903968","High","BL names Cavanaugh's; 1921 Sansom / 112 S 19th corner","SD",
  "E09","ACT3 LLC (253 S 20th)","R314","543078","High","Same name and address","SD",
  "E10","Lucy's","R497","942793;1010220","High","Same name and address; holds Special Assembly Occupancy licence","SD+AE",
  "E11","Di Bruno Bros","R11233","951788;951785","High","Same operator; restaurant + retail food licences in one premises","SD+RETAIL",
  "E12","Zama","R6004","489975;503059","High","Same name and address","SD",
  "E13","Dear Daphne","R6846","0968016","Medium","BL names Dear Daphne at 1909 Walnut; PLCB premises 1930 Sansom (through-lot; owner 1911 Walnut Street LLC)","SD",
  "E14","The Bunker","R356","536786;539372","High","Same name and address","SD",
  "E15","Little Water","R7351","0964412;0971488","High","Same name and address","SD",
  "E16","Restaurant Aleksandar","R631","900534","High","Same name and address","SD",
  "E17","Her Place Supper Club","R768","885654","High","Same name and address","SD",
  "E18","Kfar","R40281","816649","High","Same licensee name; 110 vs 112 S 19th (corner of Chestnut)","SD",
  "E19","Alaska Cafe","R10350","774721;318174","High","Same name and address","SD",
  "E20","Huayu Co Inc (1930-34 Chestnut)","R107","568570;584433","High","Same name and address","SD",
  "E21","Pietro's Walnut Pizzeria","R4548","208933","High","Same name and address","SD",
  "E22","Bar Bombon (Marquis Latin Philly)","R7435","774999;679146","High","Same name and address","SD",
  "E23","Eighteenth Street Restaurant Partners (122 S 18th)","R896","522107;522109","High","Same name and address","SD",
  "E24","1715 on Rittenhouse (Rittenhouse Operations)","R9010","891611","High","Same name and address","SD",
  "E25","1920 Philly LLC (1920 Chestnut)","R11249","","Unmatched","No same-name City licence; Veda Inc holds a food licence at 1920-22 Chestnut - possible co-location, unresolved","SD",
  "E26","Catholic Philopatrian Literary Institute","CC2421","","Unmatched","Private club; no City food licence in extract","FO|EAF",
  "E27","AKA Rittenhouse Square (hotel + A Kitchen + Bar)","H31216","936340;599397;536732;0971491","High","Same licensee (AKA RS Liquor LLC) and address","VA+SD",
  "E28","Tomboi","R747","444009","High","Same licensee; PLCB 1705 Chancellor vs BL 1704 Walnut (through-lot)","SD",
  "E29","Marathon on the Square","R4405","313086;618920","Medium","Same address 1839 Spruce; licensee names differ (Marathon Grill Rittenhouse Square LP vs Rittenhouse Grill Associates LP)","SD",
  "E30","1907 Sansom St Operating Inc","R10265","836196","High","Same licensee name; 1901 vs 1905-07 Sansom","SD",
  "E31","La Fontana Della Citta","R2115","0991258","High","Same name/address; BL licence passed expiration (2026-10-14) - not counted as current","SD",
  "E32","Barclay Prime","R1799","312887","High","Same name and address","SD",
  "E33","Via Locust (Locust Street Restaurant Group)","R2125","830827;837757;1016114","High","Same licensee and address","SD",
  "E34","DCEP LLC (108-110 S 18th)","R1368","718221;783571;0976339","High","Same licensee; two City food licences (108 and 110 S 18th) treated as one premises - unresolved","SD",
  "E35","Dancerobot","R1252","0989452","High","Same name and address","SD",
  "E36","The Prime Rib","R1273","","Unmatched","No City food licence in extract (1701 Locust, Warwick building)","SD",
  "E37","Rouge 98","R272","894558;322370;0975685","High","Same name; 201 vs 205 S 18th","SD",
  "E38","Gran Caffe L'Aquila","R6598","648848;662488","High","Same name and address","SD",
  "E39","Smallville Restaurant Associates (1805-09 Walnut)","R11124","0985289;946260","High","Same name and address","SD",
  # City food-service licensees with no current PLCB retail licence
  "E40","Goldie (112 S 19th)","","913993","n/a","City licence only","PFS|TO|SD",
  "E41","Barry's Bootcamp (food service)","","829278","n/a","City licence only; food service may be accessory to a fitness use","ACC|PFS|TO",
  "E42","The Ground Coffee Plants and Gifts","","949392;1002980","n/a","City licence only","PFS|TO|SD",
  "E43","Kismet Bagels","","917879","n/a","City licence only","PFS|TO|SD",
  "E44","Hip City Veg","","560746","n/a","City licence only","PFS|TO|SD",
  "E45","Moment Gelato and Coffee","","1013438","n/a","City licence only","PFS|TO|SD",
  "E46","Farina Pasta and Noodle","","950315","n/a","City licence only","PFS|TO|SD",
  "E47","Bluestone Lane","","687438","n/a","City licence only","PFS|TO|SD",
  "E48","Sushi Awarsei (1730-32 Chestnut)","","0981474","n/a","City licence only; same address as Di Bruno Bros - may operate inside it","PFS|TO|SD",
  "E49","Zacs Halal","","1016953","n/a","City licence only","PFS|TO|SD",
  "E50","Starbucks (1801 Spruce)","","577087","n/a","City licence only","PFS|TO|SD",
  "E51","Essex Squeeze (1909 Walnut)","","0972727","n/a","City licence only","PFS|TO|SD",
  "E52","Red Machi 209","","1012219","n/a","City licence only","PFS|TO|SD",
  "E53","Vibrant Coffee Roasters","","870955;915430","n/a","City licence only","PFS|TO|SD",
  "E54","Rittenhouse Maxx's Produce","","0966138","n/a","City licence only; principal use may be grocery retail","RETAIL|PFS|TO",
  "E55","Malai (Twenty-Two Desserts)","","0995448","n/a","City licence only","PFS|TO|SD",
  "E56","The Bakeshop on 20th","","644771","n/a","City licence only","PFS|TO|SD",
  "E57","Pure Sweets","","770018","n/a","City licence only (30+ seats)","TO|SD",
  "E58","Holyguacamoly","","1019985","n/a","City licence only (30+ seats)","TO|SD",
  "E59","Blank Street (1801 Spruce)","","1017539","n/a","City licence only (30+ seats)","TO|SD",
  "E60","La Colombe","","520046","n/a","City licence only (30+ seats)","TO|SD",
  "E61","Veda Inc (1920-22 Chestnut)","","721646","n/a","City licence only (30+ seats); see E25","TO|SD",
  "E62","Luna BYOB","","0956536","n/a","City licence only (30+ seats); BYOB","TO|SD",
  "E63","Walnut Garden (outdoor)","","0980066","n/a","City outdoor food licence only","PFS|TO|SD")

# candidate codes -> official Zoning Code use names
use_name <- c(SD = "Sit-Down Restaurant", TO = "Take-Out Restaurant", PFS = "Prepared Food Shop",
              AE = "Assembly and Entertainment (general)", NC = "Nightclubs and Public Entertainment Venue",
              EAF = "Event Assembly Facility", VA = "Visitor Accommodations",
              FO = "Fraternal Organization", RETAIL = "Food, Beverages, and Groceries",
              ACC = "Accessory use (principal use unknown)")

split_ids <- function(x) if (is.na(x) || x == "") character(0) else strsplit(x, ";")[[1]]
xw_long <- bind_rows(
  xw |> select(est_id, plcb) |> mutate(id = map(plcb, split_ids), src = "PLCB") |> unnest(id),
  xw |> select(est_id, bl)   |> mutate(id = map(bl, split_ids),   src = "BL")   |> unnest(id)) |>
  select(est_id, src, id)

# every included licence must map to exactly one establishment
incl_bl <- bl |> filter(current, role != "not relevant")
incl_pl <- pl |> filter(current, role == "primary")
orphans_bl <- setdiff(incl_bl$licensenum, xw_long$id[xw_long$src == "BL"])
orphans_pl <- setdiff(incl_pl$License.Number, xw_long$id[xw_long$src == "PLCB"])
cat("Included BL licences not in crosswalk:", paste(orphans_bl, collapse = ", "), "\n")
cat("Included PLCB licences not in crosswalk:", paste(orphans_pl, collapse = ", "), "\n")
stopifnot(!any(duplicated(xw_long$id)))

# ---- 3. Representative location per establishment -----------------------
# Prefer the City licence geocode (City address system); else PLCB point.
bl_pts <- bl |> filter(licensenum %in% xw_long$id) |>
  left_join(xw_long |> filter(src == "BL"), by = c("licensenum" = "id")) |>
  mutate(rank = case_when(licensetype == "Food Preparing and Serving (30+ SEATS)" ~ 1,
                          licensetype == "Food Preparing and Serving" ~ 2,
                          licensetype == "Food Establishment, Outdoor" ~ 3, TRUE ~ 9))
pl_pts <- pl |> filter(License.Number %in% xw_long$id) |>
  left_join(xw_long |> filter(src == "PLCB"), by = c("License.Number" = "id"))

loc_bl <- bl_pts |> filter(rank < 9) |> group_by(est_id) |> slice_min(rank, n = 1, with_ties = FALSE) |>
  ungroup() |> transmute(est_id, loc_source = "City licence geocode", address = address,
                         opa = opa_account_num)
loc_pl <- pl_pts |> filter(!est_id %in% loc_bl$est_id) |>
  transmute(est_id, loc_source = "PLCB point", address = str_squish(sub(",.*$", "", Premises.Address)),
            opa = NA_character_)
loc <- bind_rows(loc_bl, loc_pl)

# ---- 4. Spatial join to zoning -------------------------------------------
zj <- st_join(loc, zbase |> select(zone = long_code), join = st_intersects)
dup_match <- zj |> st_drop_geometry() |> count(est_id) |> filter(n > 1)
zj <- zj |> group_by(est_id) |> slice(1) |> ungroup()

# distance to nearest boundary with a *different* base district
zb_diss <- zbase |> group_by(long_code) |> summarise(geometry = st_union(geom), .groups = "drop")
dist_other <- map_dbl(seq_len(nrow(zj)), function(i) {
  z <- zj$zone[i]
  other <- zb_diss |> filter(long_code != z | is.na(z))
  min(as.numeric(st_distance(zj[i, ], other)))
})
# points falling in street ROW (no zoning polygon): nearest district
nearest_zone <- zb_diss$long_code[st_nearest_feature(zj, zb_diss)]
zj <- zj |> mutate(dist_other_ft = round(dist_other, 1),
                   zone_note = case_when(is.na(zone) ~ paste0("Point in street ROW; nearest district ", nearest_zone[is.na(zone)]),
                                         dist_other_ft < 20 ~ "Within 20 ft of a different district",
                                         TRUE ~ ""),
                   zone = coalesce(zone, nearest_zone))

# PLCB point as a second opinion on zoning
pl_zone <- st_join(pl_pts |> select(est_id), zbase |> select(zone_plcb = long_code)) |>
  st_drop_geometry() |> group_by(est_id) |> summarise(zone_plcb = paste(unique(na.omit(zone_plcb)), collapse = "/"))

# overlays at the point
ov <- st_join(zj |> select(est_id), zover |> select(overlay_name)) |> st_drop_geometry() |>
  filter(!is.na(overlay_name)) |>
  mutate(short = sub("^/CTR Center City Overlay District - ", "/CTR ", overlay_name)) |>
  group_by(est_id) |> summarise(overlays = paste(sort(unique(short)), collapse = "; "))
zj$in_cw_polygon <- lengths(st_intersects(zj, cw)) > 0

# address frontage check: any linked address on Chestnut or Walnut?
all_addr <- bind_rows(
  bl_pts |> st_drop_geometry() |> transmute(est_id, a = address),
  pl_pts |> st_drop_geometry() |> transmute(est_id, a = Premises.Address)) |>
  group_by(est_id) |> summarise(addresses = paste(unique(str_squish(sub(",.*$", "", a))), collapse = " | "),
                                cw_frontage_addr = any(grepl("CHESTNUT ST|WALNUT ST", a)))

# ---- 5. Permission lookup (verified against Code text, Oct 2026) ---------
pm <- read_csv("outputs/analysis/zoning_permission_matrix.csv", show_col_types = FALSE)
retail_base <- c("CMX-2"="Y","CMX-3"="Y","CMX-4"="Y","CMX-5"="Y","RM-1"="N","RM-4"="N","RMX-3"="Y","SP-PO-A"="N")
status_of <- function(zone, cw, code) {
  if (code == "ACC") return("?")
  if (code == "RETAIL") return(retail_base[[zone]])
  r <- pm |> filter(district == zone, use == use_name[[code]])
  if (cw) r$status_if_fronting_chestnut_walnut else r$base_district_status
}
# "|" = alternative classifications; "+" = uses present together (strictest governs)
eval_candidates <- function(zone, cw, cand) {
  alts <- strsplit(cand, "\\|")[[1]]
  alt_status <- map_chr(alts, function(a) {
    parts <- strsplit(a, "\\+")[[1]]
    s <- map_chr(parts, ~ status_of(zone, cw, .x))
    if (any(s == "?")) "?" else if (any(s == "N")) "N" else if (any(s == "S")) "S" else "Y"
  })
  u <- unique(alt_status)
  list(status = if (length(u) == 1 && u != "?") u else "MIXED",
       detail = paste0(alts, "=", alt_status, collapse = "; "))
}
lab <- c(Y = "BY-RIGHT", S = "SPECIAL APPROVAL REQUIRED", N = "NOT PERMITTED BY RIGHT", MIXED = "UNDETERMINED")

# ---- 6. Permits and ZBA appeals (City records behind Atlas) --------------
parse_addr <- function(a) {
  a <- toupper(a); a <- sub(",.*$", "", a)
  parts <- str_split(a, "\\s*&\\s*")[[1]]
  map_dfr(parts, function(p) {
    p <- str_squish(sub("\\s+(SUITE|UNIT|APT|#).*$", "", p))
    m <- str_match(p, "^(\\d+)(?:-(\\d+))?\\s+(.*)$")
    if (is.na(m[1])) return(tibble())
    lo <- as.integer(m[2]); hi <- m[3]
    hi <- if (is.na(hi)) lo else as.integer(if (nchar(hi) < nchar(m[2])) paste0(substr(m[2], 1, nchar(m[2]) - nchar(hi)), hi) else hi)
    tibble(lo = lo, hi = hi, street = str_squish(m[4]))
  })
}
est_addr <- bind_rows(
  bl_pts |> st_drop_geometry() |> transmute(est_id, a = address),
  pl_pts |> st_drop_geometry() |> transmute(est_id, a = Premises.Address)) |>
  distinct() |> mutate(p = map(a, parse_addr)) |> unnest(p) |> distinct(est_id, lo, hi, street)
est_opa <- bl_pts |> st_drop_geometry() |> filter(!is.na(opa_account_num)) |> distinct(est_id, opa = opa_account_num)

permits <- read_csv("data/derived/carto_zoning_permits_ritt.csv", col_types = cols(.default = "c")) |>
  transmute(rec = permitnumber, kind = "Zoning permit", address, opa = opa_account_num,
            date = as.Date(substr(permitissuedate, 1, 10)), text = approvedscopeofwork, result = status)
appeals <- read_csv("data/derived/carto_appeals_ritt.csv", col_types = cols(.default = "c")) |>
  filter(applicationtype %in% c("RB_ZBA", "Zoning Board of Adjustment")) |>
  transmute(rec = appealnumber, kind = paste("ZBA appeal", coalesce(appealtype, "(legacy record)")), address,
            opa = opa_account_num, date = as.Date(substr(coalesce(decisiondate, createddate), 1, 10)),
            text = appealgrounds, result = coalesce(meetingresult, decision, "result not recorded"))
recs <- bind_rows(permits, appeals) |>
  mutate(rec = paste0(if_else(kind == "Zoning permit", "ZP:", "ZBA:"), rec)) |>
  filter(grepl("RESTAURANT|EATING|DRINKING|NIGHTCLUB|ASSEMBLY AND ENTERTAINMENT|ASSEMBLY & ENTERTAINMENT|VISITOR ACCOMMODATION|HOTEL|TAKE-OUT|TAKE OUT|TAKEOUT|PREPARED FOOD|TAVERN|EAT-IN|EAT IN|BAR\\b",
               toupper(text))) |>
  mutate(p = map(address, parse_addr)) |> unnest(p, keep_empty = TRUE)

m_addr <- est_addr |> inner_join(recs, by = "street", relationship = "many-to-many") |>
  filter(lo.x <= hi.y, lo.y <= hi.x, (lo.x %% 2) == (lo.y %% 2)) |> select(est_id, rec)
m_opa  <- est_opa |> inner_join(recs, by = "opa", relationship = "many-to-many") |> select(est_id, rec)
ev <- bind_rows(m_addr, m_opa) |> distinct() |>
  left_join(recs |> distinct(rec, .keep_all = TRUE) |> select(rec, kind, date, text, result), by = "rec") |>
  mutate(short = str_squish(substr(gsub("[\r\n]+", " ", text), 1, 110)),
         approval_type = case_when(grepl("SPECIAL EXCEPTION", toupper(text)) & grepl("ZBA", kind) ~ "special exception",
                                   grepl("Variance", kind) ~ "variance",
                                   grepl("ZBA", kind) ~ "ZBA appeal",
                                   TRUE ~ "zoning permit"))
write_csv(ev |> arrange(est_id, date) |> select(est_id, rec, kind, approval_type, date, result, short),
          "outputs/analysis/zoning_approval_records_matched.csv")

# ---- 7. Assemble comparison table ----------------------------------------
lic_tbl <- bind_rows(
  bl |> st_drop_geometry() |> filter(licensenum %in% xw_long$id) |>
    transmute(id = licensenum, txt = paste0(licensetype, if_else(current, "", " [not current]")), cur = current & role != "not relevant"),
  pl |> st_drop_geometry() |> filter(License.Number %in% xw_long$id) |>
    transmute(id = License.Number, txt = paste0("PLCB ", License.Type), cur = current & role == "primary")) |>
  right_join(xw_long, by = "id") |>
  group_by(est_id) |>
  summarise(licence_types = paste(unique(txt), collapse = "; "),
            licence_ids = paste(id, collapse = "; "),
            n_current_relevant_licences = sum(cur), .groups = "drop")

out <- xw |>
  left_join(zj |> st_drop_geometry() |> select(est_id, loc_source, address, zone, dist_other_ft, zone_note, in_cw_polygon), by = "est_id") |>
  left_join(pl_zone, by = "est_id") |> left_join(ov, by = "est_id") |>
  left_join(all_addr, by = "est_id") |> left_join(lic_tbl, by = "est_id") |>
  mutate(category = case_when(grepl("Hotel", licence_types) ~ "Hotel (PLCB hotel licence)",
                              grepl("Catering Club", licence_types) ~ "Private club (PLCB catering club)",
                              grepl("Restaurant \\(Liquor\\)", licence_types) ~ "Liquor-licensed restaurant/bar",
                              TRUE ~ "Food service, no liquor licence"))

# nearest *different* district for points within 20 ft of a boundary
alt_zone <- map_chr(seq_len(nrow(zj)), function(i) {
  if (zj$dist_other_ft[i] >= 20) return(NA_character_)
  other <- zb_diss |> filter(long_code != zj$zone[i])
  other$long_code[st_nearest_feature(zj[i, ], other)]
})
out <- out |> left_join(tibble(est_id = zj$est_id, alt_zone = alt_zone), by = "est_id")
res <- pmap(list(out$zone, out$in_cw_polygon, out$cw_frontage_addr, out$candidates, out$alt_zone),
            function(z, cwp, cwa, cand, az) {
  a <- eval_candidates(z, cwp, cand)
  b <- eval_candidates(z, cwa, cand)
  if (cwp != cwa && a$status != b$status)
    return(list(status = "MIXED", detail = paste0("overlay ambiguous: polygon->", a$detail, " / frontage->", b$detail), loc_amb = TRUE))
  if (!is.na(az)) {
    c2 <- eval_candidates(az, cwp, cand)
    if (c2$status != a$status)
      return(list(status = "MIXED", detail = paste0("boundary: ", z, "->", a$detail, " / ", az, "->", c2$detail), loc_amb = TRUE))
  }
  c(a, loc_amb = cwp != cwa)
})
out$status_code <- map_chr(res, "status")
out$status_detail <- map_chr(res, "detail")
out$overlay_ambiguous <- map_lgl(res, "loc_amb")

ev_sum <- ev |> group_by(est_id) |> arrange(date) |>
  summarise(approval_records = paste0(rec, " (", kind, ", ", date, ", ", result, ")", collapse = " || "),
            zba_granted = any(grepl("ZBA", kind) & grepl("GRANT|APPROVED", toupper(result))),
            zba_granted_rec = paste(sub("^ZBA:", "", rec[grepl("ZBA", kind) & grepl("GRANT|APPROVED", toupper(result))]), collapse = "; "),
            permit_post2012 = any(kind == "Zoning permit" & date >= CODE_2012),
            zba_no_result = any(grepl("ZBA", kind) & result == "result not recorded"),
            pre2012_record = any(date < CODE_2012, na.rm = TRUE), .groups = "drop")
out <- out |> left_join(ev_sum, by = "est_id") |>
  mutate(across(c(zba_granted, permit_post2012, zba_no_result, pre2012_record), ~ coalesce(.x, FALSE)))

out <- out |> mutate(
  regulatory_classification = lab[status_code],
  potential_zoning_use = map_chr(candidates, function(c) {
    alts <- strsplit(c, "\\|")[[1]]
    paste(map_chr(alts, ~ paste(use_name[strsplit(.x, "\\+")[[1]]], collapse = " + ")), collapse = " OR ")}),
  classification_basis = case_when(
    grepl("\\|", candidates) & status_code != "MIXED" ~ "Use type uncertain, but every candidate use has the same status",
    grepl("\\|", candidates) ~ "Use type uncertain and candidates differ in status",
    category == "Liquor-licensed restaurant/bar" ~ "PLCB restaurant licence implies >=30 seats and principal food service -> Sit-Down Restaurant (probable)",
    category == "Hotel (PLCB hotel licence)" ~ "PLCB hotel licence -> Visitor Accommodations (on-site restaurant treated as part of hotel)",
    TRUE ~ "Single candidate use"),
  authorization_evidence = case_when(
    status_code == "Y" ~ "Not required for use (by right); use registration not checked",
    zba_granted ~ paste0("ZBA approval on record: ", zba_granted_rec),
    permit_post2012 ~ "Zoning permit for eating/drinking use issued after 2012 Code at this address (approval implied; tenant match and ZBA record not confirmed)",
    zba_no_result ~ "ZBA application for eating/drinking use on record; outcome not recorded in dataset",
    pre2012_record ~ "Use approved/permitted before 2012 Code (possible prior approval or lawful nonconforming status)",
    TRUE ~ "No matching approval found in City permit/appeal records (2007-2026)"),
  verification_status = case_when(
    status_code == "MIXED" ~ "UNVERIFIED - classification or location ambiguous",
    status_code == "Y" & match_confidence %in% c("High","n/a") & zone_note == "" & !overlay_ambiguous ~ "Verified by rule",
    status_code == "Y" ~ "Verified by rule - check flags",
    zba_granted ~ "Not by right; approval verified (ZBA)",
    TRUE ~ "Not by right; approval NOT verified - check Atlas"),
  flags = pmap_chr(list(zone_note, overlay_ambiguous, match_confidence, zone, zone_plcb, n_current_relevant_licences, match_note),
    function(zn, oa, mc, z, zp, n, mn) {
      f <- c(if (zn != "") zn, if (oa) "Overlay: point and street frontage disagree",
             if (mc %in% c("Medium","Unmatched")) paste("Licence match", tolower(mc)),
             if (!is.na(zp) && zp != "" && !grepl(z, zp, fixed = TRUE)) paste0("PLCB point falls in ", zp),
             if (n == 0) "No current primary licence counted",
             if (grepl("unresolved|expiration|accessory|grocery|inside", mn)) "See match note")
      paste(f, collapse = "; ")}))

# ---- 7b. Manual review of every non-by-right / undetermined case --------
# Each matched permit/appeal record was read in full (2026-10-18). Records
# are address-level: a record can concern a previous tenant. evidence_level:
#   "Verified"  = record's scope matches this establishment's use and premises
#   "Partial"   = address-level approval of an eating/drinking use; tenant link unconfirmed
#   "None found"= no relevant approval in City records 2007-2026
mr <- tribble(
  ~est_id, ~override_class, ~evidence_level, ~review_note,
  "E04", NA, "None found", "No approval for the hotel (Visitor Accommodations) use in 2007-2026 records; 2010 ZBA grant 12090 concerns a sushi-restaurant tenant (Space 105). A pre-2007 variance or lawful nonconforming status is possible but unverified.",
  "E10", NA, "Verified", "ZBA special exception granted 2023-05-08 (ZP-2022-010220): sit-down restaurant + assembly & entertainment; provisos: no exterior music, A&E only in basement. Refusal cited Table 14-502-2 (Chestnut & Walnut West).",
  "E11", NA, "None found", "No eating/drinking approval found for 1730-32 Chestnut in 2007-2026 records; use may predate the 2012 Code.",
  "E13", NA, "Verified", "ZBA grant 2023-04-24 (ZP-2023-001038) preserving unity of use for a sit-down restaurant across 1907-17 Walnut / 1904-40 Sansom; sit-down restaurant permit ZP-2022-012503.",
  "E18", NA, "Partial", "Zoning permit 622901 (2015) approved sit-down restaurant use on floor 1 at 1900-06 Chestnut (unity of use); no ZBA record matched.",
  "E20", NA, "Partial", "2010 ZBA grant 13904 (pre-2012 Code) for a take-out restaurant with seating and live entertainment at 1930-34 Chestnut; link to current operator unconfirmed.",
  "E21", NA, "Partial", "2008 ZBA grant 4701 (pre-2012 Code) to expand an existing eat-in/take-out restaurant at 1714 Walnut; restaurant use predates current Code.",
  "E24", NA, "Partial", "Zoning permit ZP-2026-007356 (Jul 2026) for Visitor Accommodations at 1711-17 Rittenhouse Sq (also not by right in RM-1, so prior relief is implied but not matched). No record for a restaurant use.",
  "E25", NA, "None found", "No eating/drinking approval found at 1920 Chestnut (2012 deck permit only).",
  "E27", "SPECIAL APPROVAL REQUIRED", "Verified", "Location ambiguity resolved by record: ZBA grant 19302 (Dec 2012) of a special exception for a sit-down restaurant (Space D) at 135 S 18th shows Table 14-502-2 was applied to this lot. Hotel use itself is by right in CMX-5.",
  "E28", "UNDETERMINED", "None found", "Liquor premises at 1705 Chancellor; City licence at 1704 Walnut, where a 2021 permit approved apparel retail. Whether the restaurant occupies a lot fronting Walnut (overlay applies) is unresolved.",
  "E29", NA, "None found", "No approval found for 1839-41 Spruce in 2007-2026 records.",
  "E38", NA, "Verified", "ZBA special exception granted 2013-08-28 (21023) for a sit-down restaurant, floors 1-2, 1716 Chestnut; extension granted 2014 (22575).",
  "E39", NA, "Verified", "ZBA special exception granted 2024-01-04 (ZP-2023-006485) for a sit-down restaurant; permit ZP-2024-000626.",
  "E48", NA, "None found", "No approval found for this tenant; may operate within Di Bruno Bros premises (1730-32 Chestnut).",
  "E49", NA, "Partial", "2016 ZBA grant 26687 for a take-out restaurant in tenant space C at 1800 Chestnut (space A also take-out as previously approved); tenant link unconfirmed.",
  "E51", NA, "None found", "No approval specific to this tenant; the building's 2023 unity-of-use grant covers a sit-down restaurant (Dear Daphne).",
  "E52", NA, "Partial", "2010 ZBA grant 12090 (pre-2012 Code) for signs accessory to a proposed eat-in & take-out sushi restaurant in Space 105, 202-10 W Rittenhouse Sq; tenant link unconfirmed.",
  "E53", NA, "Partial", "2013 ZBA grant 19531 for a take-out restaurant with seating, ground-floor rear, 222 W Rittenhouse Sq; tenant link unconfirmed.",
  "E60", NA, "None found", "No eating/drinking approval found for 1901-05 Walnut.",
  "E61", NA, "None found", "No eating/drinking approval found for 1920-22 Chestnut.",
  "E62", NA, "None found", "No approval found for 227 S 20th in 2007-2026 records.",
  "E63", NA, "Verified", "ZBA grant 2024-03-15 (ZP-2023-010662): sit-down restaurant with assembly & entertainment in a tent; TEMPORARY special exception expiring 2028-03-31.",
  "E08", NA, "n/a", "112 S 19th: point falls in the Chestnut & Walnut overlay polygon but address is on 19th St; lot frontage unresolved. Only a 2022 sign permit (Federal Donuts/Goldie) found.",
  "E40", NA, "n/a", "Same multi-tenant building as E08; overlay applicability unresolved.",
  "E41", NA, "n/a", "Same building as E08; food service may also be accessory to a fitness use.",
  "E37", NA, "n/a", "201/205 S 18th (corner of Walnut): point in overlay polygon, address on 18th St; frontage unresolved. No restaurant approval found.",
  "E09", NA, "n/a", "Point 10 ft from RM-4 boundary: by right if CMX-2, not permitted by right if RM-4.",
  "E31", NA, "n/a", "Point 19 ft from RM-4 boundary; 2011 lot-line permit describes an existing first-floor restaurant (pre-2012).",
  "E54", NA, "n/a", "Boundary case (CMX-2/RM-4) and principal use may be grocery retail.",
  "E55", NA, "n/a", "Boundary case (CMX-2/RM-4); use type (take-out vs. sit-down) unknown.",
  "E56", NA, "n/a", "Boundary case (CMX-2/RM-4); use type unknown.",
  "E50", NA, "n/a", "Status depends on use type in CMX-2 (Take-Out = special exception). 2012 ZBA grant 17414 for a take-out restaurant with seating at 1801 Spruce (address-level).",
  "E59", NA, "n/a", "Same address as E50; 2012 take-out restaurant approval at 1801 Spruce is address-level only.")
stopifnot(!any(duplicated(mr$est_id)))
out <- out |> left_join(mr, by = "est_id") |>
  mutate(regulatory_classification = coalesce(override_class, regulatory_classification),
         authorization_evidence = if_else(!is.na(review_note) & regulatory_classification != "BY-RIGHT",
                                          paste0("[", evidence_level, "] ", review_note), authorization_evidence),
         verification_status = case_when(
           regulatory_classification == "UNDETERMINED" ~ "UNVERIFIED - classification or location ambiguous",
           regulatory_classification == "BY-RIGHT" ~ verification_status,
           evidence_level == "Verified" ~ "Not by right; approval verified in City records",
           evidence_level == "Partial" ~ "Not by right; address-level approval only - verify tenant in Atlas",
           TRUE ~ "Not by right; no approval found - verify in Atlas"))
# any non-by-right/undetermined case left without manual review?
stopifnot(all(!is.na(out$review_note[out$regulatory_classification != "BY-RIGHT"])))

final <- out |>
  transmute(est_id, establishment, category, licence_types, licence_ids, n_current_relevant_licences,
            address, all_addresses = addresses, location_source = loc_source,
            base_zoning_district = zone, plcb_point_district = zone_plcb, dist_to_other_district_ft = dist_other_ft,
            overlays, chestnut_walnut_west_overlay = in_cw_polygon, chestnut_walnut_frontage_address = cw_frontage_addr,
            potential_zoning_use, classification_basis, status_by_candidate = status_detail,
            regulatory_classification, authorization_evidence, approval_records,
            verification_status, flags, match_confidence, match_note) |>
  arrange(est_id)
write_csv(final, "outputs/analysis/licensing_zoning_comparison.csv", na = "")
st_write(zj |> select(est_id) |> left_join(final, by = "est_id"),
         "data/derived/establishments_zoning.gpkg", delete_dsn = TRUE, quiet = TRUE)

# ---- 8. Summary counts ----------------------------------------------------
n_lic <- lic_audit |> filter(included) |> summarise(n = sum(n)) |> pull(n)
cat("Relevant current licence records:", n_lic, "\n")
print(lic_audit |> filter(included) |> group_by(source, role) |> summarise(n = sum(n), .groups = "drop"))
cat("Identifiable establishments:", nrow(final), "\n")
print(count(final, category))
print(count(final, base_zoning_district, sort = TRUE))
print(count(final, regulatory_classification) |> mutate(pct = round(100 * n / sum(n), 1)))
print(count(final, category, regulatory_classification))
print(count(final, verification_status))
cat("Duplicate zoning matches:", nrow(dup_match), "\n")
