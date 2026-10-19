# 01_governance_zoning.R
# Governance and zoning geography for the Rittenhouse Square study area.
# Re-implements the clipping in data-precessing.R in a projected CRS
# (EPSG:2272, PA State Plane South, US ft) with geometry repair, and
# writes the clipped layers to data/derived/ so later steps reuse them.
# Run from the assignment_2/ directory.

suppressMessages({library(sf); library(tidyverse)})
sf_use_s2(FALSE)
P <- 2272
dir.create("data/derived", showWarnings = FALSE)
dir.create("outputs/analysis", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

rd <- function(f) st_read(f, quiet = TRUE) |> st_transform(P) |> st_make_valid()

sa <- rd("data/studyAreas2026.geojson") |> filter(Name == "RITTENHOUSE SQUARE")
sa_area <- as.numeric(st_area(sa))

clip <- function(x) {
  x <- x[lengths(st_intersects(x, sa)) > 0, ]
  out <- suppressWarnings(st_intersection(x, st_geometry(sa)))
  out$clip_sqft <- as.numeric(st_area(out))
  out
}

council <- clip(rd("data/Council_Districts_2024.geojson"))
police  <- clip(rd("data/Boundaries_District.geojson"))
rco     <- clip(rd("data/Zoning_RCO.geojson"))
bid     <- clip(rd("data/business_improvement_districts.shp"))
corr    <- clip(rd("data/Commercial_Corridors.geojson"))
vend    <- clip(rd("data/Vending_Special_Districts.geojson"))
zbase   <- clip(rd("data/Zoning_BaseDistricts.geojson"))
zover   <- clip(rd("data/Zoning_Overlays.geojson"))

st_write(sa,    "data/derived/study_area.gpkg",       delete_dsn = TRUE, quiet = TRUE)
st_write(zbase, "data/derived/zoning_base_clip.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(zover, "data/derived/zoning_overlay_clip.gpkg", delete_dsn = TRUE, quiet = TRUE)
st_write(council, "data/derived/council_clip.gpkg",   delete_dsn = TRUE, quiet = TRUE)
st_write(bid,   "data/derived/bid_clip.gpkg",         delete_dsn = TRUE, quiet = TRUE)

# ---- Governance summary --------------------------------------------------
pct <- function(a) round(100 * a / sa_area, 1)
gov <- bind_rows(
  council |> st_drop_geometry() |> group_by(name = paste("Council District", DISTRICT)) |>
    summarise(a = sum(clip_sqft)) |> mutate(layer = "Council District",
      source = "Council_Districts_2024.geojson (OpenDataPhilly)"),
  police |> st_drop_geometry() |> group_by(name = paste("Police District", as.integer(dist_numc))) |>
    summarise(a = sum(clip_sqft)) |> mutate(layer = "Police District",
      source = "Boundaries_District.geojson (Philadelphia Police Dept.)"),
  rco |> st_drop_geometry() |> group_by(name = organization_name) |>
    summarise(a = sum(clip_sqft)) |> mutate(layer = "Registered Community Organization (RCO)",
      source = "Zoning_RCO.geojson (PCPC)"),
  bid |> st_drop_geometry() |> group_by(name = organizati) |>
    summarise(a = sum(clip_sqft)) |> mutate(layer = "Business Improvement District (BID/SSD)",
      source = "business_improvement_districts.shp (Commerce Dept.)"),
  corr |> st_drop_geometry() |> group_by(name = paste0(name, " (", p_dist, ")"),
      manager = if_else(is.na(crm_org), "No corridor manager recorded (crm_org blank)", crm_org)) |>
    summarise(a = sum(clip_sqft), .groups = "drop") |>
    mutate(layer = "Commercial Corridor / Corridor Manager",
      source = "Commercial_Corridors.geojson (PCPC/Commerce)"),
  vend |> st_drop_geometry() |> group_by(name = paste0(NEIGH_BUSI, " Special Vending District (Code ", CODE_REF, ")")) |>
    summarise(a = sum(clip_sqft)) |> mutate(layer = "Special Vending District",
      source = "Vending_Special_Districts.geojson")
) |>
  transmute(layer, name, manager, pct_of_study_area = pct(a), source)
write_csv(gov, "outputs/analysis/governance_summary.csv", na = "")

# ---- Zoning base-district summary ---------------------------------------
zone_area <- sum(zbase$clip_sqft)   # zoned land excludes street right-of-way
zs <- zbase |> st_drop_geometry() |>
  group_by(zoning_district = long_code, zoning_group = zoninggroup) |>
  summarise(n_polygons = n(), acres = sum(clip_sqft) / 43560, .groups = "drop") |>
  mutate(pct_of_zoned_land = round(100 * acres * 43560 / zone_area, 1),
         acres = round(acres, 2)) |>
  arrange(desc(acres))
write_csv(zs, "outputs/analysis/zoning_summary.csv")
cat(sprintf("Study area %.2f ac; zoned land %.2f ac (%.0f%%; remainder is street ROW)\n",
            sa_area / 43560, zone_area / 43560, 100 * zone_area / sa_area))

# ---- Overlay summary -----------------------------------------------------
os <- zover |> st_drop_geometry() |>
  group_by(overlay_name, overlay_symbol, type, code_section) |>
  summarise(acres = round(sum(clip_sqft) / 43560, 2), .groups = "drop") |>
  mutate(pct_of_study_area = pct(acres * 43560),
         nighttime_use_relevance = case_when(
           grepl("Chestnut and Walnut Street Area", overlay_name) ~
             "Table 14-502-2: Eating & Drinking Establishments need special exception (not on residentially-zoned lots); Take-Out Restaurant special exception",
           grepl("Center City Commercial District Control Area", overlay_name) ~
             "Table 14-502-2: no eating/drinking or assembly controls (height/bulk & household-living controls only)",
           grepl("Rittenhouse Square Residential Area", overlay_name) ~
             "Table 14-502-2 note [8]: group living / student housing limits only",
           grepl("Parking Garage Ground Floor", overlay_name) ~ "14-502(6)(d): ground-floor parking controls; no nighttime-use controls",
           grepl("VDO", overlay_symbol) ~ "14-529: dwelling-unit/ADU controls only; no nighttime-use controls",
           grepl("NIS", overlay_symbol) ~ "14-540: narcotics injection sites only",
           TRUE ~ "No nighttime use controls identified")) |>
  arrange(desc(acres))
write_csv(os, "outputs/analysis/zoning_overlay_summary.csv")

# ---- Nighttime use permission matrix (Code-verified, Oct 2026) ------------
# Base tables: Table 14-602-1 (residential), 14-602-2 (commercial),
# 14-602-4 (special purpose). Overlay: Table 14-502-2. Y = by right,
# S = special exception, N = not allowed / not listed (prohibited).
uses <- c("Prepared Food Shop", "Take-Out Restaurant", "Sit-Down Restaurant",
          "Nightclubs and Public Entertainment Venue", "Assembly and Entertainment (general)",
          "Event Assembly Facility", "Visitor Accommodations", "Fraternal Organization")
base <- tribble(
  ~district, ~PFS, ~TO, ~SD, ~NC, ~AE, ~EAF, ~VA, ~FO,
  "CMX-2",   "Y", "S", "Y", "S", "S", "S", "N", "Y",
  "CMX-3",   "Y", "Y", "Y", "S", "S", "S", "Y", "Y",
  "CMX-4",   "Y", "Y", "Y", "Y", "Y", "Y", "Y", "Y",
  "CMX-5",   "Y", "Y", "Y", "Y", "Y", "Y", "Y", "Y",
  "RM-1",    "N", "N", "N", "N", "N", "N", "N", "S",
  "RM-4",    "N", "N", "N", "N", "N", "N", "N", "S",
  "RMX-3",   "Y", "Y", "Y", "N", "N", "N", "Y", "S",
  "SP-PO-A", "Y", "Y", "Y", "N", "N", "N", "N", "N")
names(base)[-1] <- uses
note <- c(
  "CMX-2"   = "Table 14-602-2",
  "CMX-3"   = "Table 14-602-2",
  "CMX-4"   = "Table 14-602-2",
  "CMX-5"   = "Table 14-602-2",
  "RM-1"    = "Table 14-602-1; commercial services not allowed",
  "RM-4"    = "Table 14-602-1; commercial services not allowed",
  "RMX-3"   = "Table 14-602-1 note [5]: retail/commercial service <=25% of GFA; assembly & entertainment not listed (prohibited)",
  "SP-PO-A" = "Table 14-602-4 note [5]: eating & drinking only if co-located with and smaller than a primary park/open-space use")
pm <- base |> pivot_longer(-district, names_to = "use", values_to = "base_district_status") |>
  mutate(overlay_chestnut_walnut_west = case_when(
           !district %in% c("CMX-2","CMX-3","CMX-4","CMX-5","SP-PO-A") ~ "No overlay change (note [4]: residential lots exempt)",
           use %in% c("Prepared Food Shop","Take-Out Restaurant","Sit-Down Restaurant") ~ "S (Table 14-502-2)",
           TRUE ~ "No overlay change"),
         status_if_fronting_chestnut_walnut = case_when(
           base_district_status == "N" ~ "N",
           grepl("^S", overlay_chestnut_walnut_west) ~ "S",
           TRUE ~ base_district_status),
         code_reference = note[district]) |>
  filter(district %in% unique(zs$zoning_district))
write_csv(pm, "outputs/analysis/zoning_permission_matrix.csv")
print(zs); print(os |> select(overlay_name, acres))
