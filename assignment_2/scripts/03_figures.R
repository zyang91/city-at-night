# 03_figures.R — memo figures. Run from assignment_2/ after scripts 01 and 02.
suppressMessages({library(sf); library(tidyverse)})
sf_use_s2(FALSE)

sa    <- st_read("data/derived/study_area.gpkg", quiet = TRUE)
zbase <- st_read("data/derived/zoning_base_clip.gpkg", quiet = TRUE)
zover <- st_read("data/derived/zoning_overlay_clip.gpkg", quiet = TRUE)
est   <- st_read("data/derived/establishments_zoning.gpkg", quiet = TRUE)
cw    <- zover |> filter(grepl("Chestnut and Walnut Street Area", overlay_name)) |>
  summarise(geom = st_union(geom))

ink <- "#0b0b0b"; ink2 <- "#52514e"; muted <- "#8a8984"; surf <- "#fcfcfb"
# Official City zoning colours: renderer of the Zoning_BaseDistricts ArcGIS service
# (services.arcgis.com/fLeGjb7u4uXqeF9q/.../Zoning_BaseDistricts/FeatureServer/0), read Oct 2026.
zone_grp <- c("CMX-5" = "CMX-4/5", "CMX-4" = "CMX-4/5", "CMX-3" = "CMX-3", "CMX-2" = "CMX-2",
              "RMX-3" = "RMX-3", "RM-4" = "RM-1/RM-4", "RM-1" = "RM-1/RM-4", "SP-PO-A" = "SP-PO-A")
grp_fill <- c("CMX-4/5" = "#850000", "CMX-3" = "#eb0000", "CMX-2" = "#ff7070",
              "RMX-3" = "#ff8138", "RM-1/RM-4" = "#ffa72b", "SP-PO-A" = "#138c00")
grp_lab <- c("CMX-4/5" = "Commercial mixed-use, high intensity (CMX-4/5)",
             "CMX-3" = "Commercial mixed-use (CMX-3)",
             "CMX-2" = "Neighborhood commercial mixed-use (CMX-2)",
             "RMX-3" = "Residential mixed-use (RMX-3)",
             "RM-1/RM-4" = "Multi-family residential (RM-1, RM-4)",
             "SP-PO-A" = "Park and open space (SP-PO-A)")
zbase$grp <- factor(zone_grp[zbase$long_code], levels = names(grp_fill))
cls_col <- c("BY-RIGHT" = "#ffffff", "SPECIAL APPROVAL REQUIRED" = "#2a78d6",
             "NOT PERMITTED BY RIGHT" = "#0b0b0b", "UNDETERMINED" = "#a3a29c")
cls_lab <- c("BY-RIGHT" = "By right", "SPECIAL APPROVAL REQUIRED" = "Special approval required",
             "NOT PERMITTED BY RIGHT" = "Not permitted by right", "UNDETERMINED" = "Undetermined")

theme_map <- theme_void(base_size = 9) +
  theme(plot.background = element_rect(fill = surf, colour = NA),
        legend.text = element_text(colour = ink2, size = 7.5),
        legend.title = element_text(colour = ink, size = 8, face = "bold"),
        plot.title = element_text(colour = ink, face = "bold", size = 10.5),
        plot.subtitle = element_text(colour = ink2, size = 8),
        plot.caption = element_text(colour = muted, size = 6.5, hjust = 0),
        legend.key.size = unit(10, "pt"), plot.margin = margin(6, 6, 6, 6))

bb <- st_bbox(sa)
map_furniture <- function() {
  x0 <- bb["xmin"] + 60; y0 <- bb["ymin"] + 70
  list(
    annotate("rect", xmin = x0, xmax = x0 + 250, ymin = y0, ymax = y0 + 18, fill = ink, colour = ink),
    annotate("rect", xmin = x0 + 250, xmax = x0 + 500, ymin = y0, ymax = y0 + 18, fill = surf, colour = ink),
    annotate("text", x = c(x0, x0 + 250, x0 + 500), y = y0 - 30, label = c("0", "250", "500 ft"),
             size = 2.3, colour = ink2),
    annotate("segment", x = bb["xmax"] - 70, xend = bb["xmax"] - 70, y = bb["ymax"] - 190, yend = bb["ymax"] - 60,
             arrow = arrow(length = unit(6, "pt"), type = "closed"), colour = ink, linewidth = 0.6),
    annotate("text", x = bb["xmax"] - 70, y = bb["ymax"] - 30, label = "N", fontface = "bold", size = 3, colour = ink))
}
src <- "Sources: City of Philadelphia zoning base districts & overlays (PCPC, OpenDataPhilly); study area (CPLN 6890). EPSG:2272."

zone_scale <- scale_fill_manual(values = grp_fill, labels = grp_lab, name = "Zoning (City standard colours)", drop = FALSE)
# label only the main areas
zl <- zbase |> mutate(a = as.numeric(st_area(geom))) |> filter(long_code %in% c("CMX-5", "CMX-4", "RM-4", "SP-PO-A")) |>
  group_by(long_code) |> slice_max(a, n = 1) |> ungroup() |> st_point_on_surface()
zl <- zl |> mutate(x = st_coordinates(zl)[, 1], y = st_coordinates(zl)[, 2],
                   lab = recode(long_code, "SP-PO-A" = "Rittenhouse Square\n(park, SP-PO-A)"),
                   y = if_else(long_code == "RM-4", y - 150, y),
                   x = if_else(long_code == "CMX-4", x + 120, x))
zone_labels <- geom_label(data = zl, aes(x, y, label = lab), size = 2.3, colour = ink, fill = surf, alpha = 0.85,
                          label.size = 0, label.padding = unit(1.2, "pt"), lineheight = 0.9)

# ---- zoning_map.png: zoning geography ---------------------------------------
p0 <- ggplot() +
  geom_sf(data = zbase, aes(fill = grp), colour = surf, linewidth = 0.3) +
  geom_sf(data = cw, fill = NA, colour = ink, linewidth = 0.5, linetype = "22") +
  geom_sf(data = sa, fill = NA, colour = ink, linewidth = 0.7) +
  zone_labels + zone_scale + map_furniture() + coord_sf(crs = 2272, datum = NA) +
  labs(title = "Zoning base districts, Rittenhouse Square study area",
       subtitle = "Dashed line: Chestnut & Walnut Street Area overlay (extra review for restaurants and bars)",
       caption = src) +
  theme_map
ggsave("outputs/figures/zoning_map.png", p0, width = 6.6, height = 4.6, dpi = 300, bg = surf)

# ---- zoning_licensed_businesses.png (Figure 1) ----------------------------
# Separate points that share one address by a small deterministic ring offset.
xy <- st_coordinates(est)
est <- est |> mutate(x = xy[, 1], y = xy[, 2]) |>
  group_by(gx = round(x / 15), gy = round(y / 15)) |>
  mutate(k = row_number(), n = n(),
         x = if_else(n > 1, x + 22 * cos(2 * pi * k / n), x),
         y = if_else(n > 1, y + 22 * sin(2 * pi * k / n), y)) |> ungroup() |>
  mutate(regulatory_classification = factor(regulatory_classification, levels = names(cls_col)))
p1 <- ggplot() +
  geom_sf(data = zbase, aes(fill = grp), colour = surf, linewidth = 0.3) +
  geom_sf(data = cw, fill = NA, colour = ink, linewidth = 0.5, linetype = "22") +
  geom_sf(data = sa, fill = NA, colour = ink, linewidth = 0.7) +
  zone_labels +
  geom_point(data = est, aes(x, y), shape = 16, size = 3.3, colour = "#ffffff") +          # halo
  geom_point(data = est, aes(x, y, colour = regulatory_classification), shape = 16, size = 2.3) +
  geom_point(data = est, aes(x, y), shape = 1, size = 2.3, stroke = 0.35, colour = ink) +   # edge
  zone_scale +
  scale_colour_manual(values = cls_col, labels = cls_lab, name = "Licensed establishments:\nzoning status of use",
                      guide = guide_legend(order = 1, override.aes = list(shape = 21, size = 2.8, stroke = 0.4,
                                                                          fill = unname(cls_col), colour = ink))) +
  map_furniture() +
  coord_sf(crs = 2272, datum = NA) +
  labs(title = "Figure 1. Zoning districts and licensed nighttime establishments (n = 63)",
       subtitle = "Dashed line = Chestnut & Walnut Street Area overlay, where restaurants and bars need a special exception.",
       caption = paste0(src, " Zoning colours: City ArcGIS service.",
                       "\nLicences: City business licences & PLCB liquor licences (teammate extracts, Oct 2026). Points sharing an address are offset slightly.",
                       "\n'Not permitted by right' does not mean unlawful: variances, special exceptions or nonconforming status may apply.")) +
  theme_map + theme(legend.position = "right")
ggsave("outputs/figures/zoning_licensed_businesses.png", p1, width = 7.4, height = 4.7, dpi = 300, bg = surf)

# ---- permission_matrix.png (Figure 2) -------------------------------------
pm <- read_csv("outputs/analysis/zoning_permission_matrix.csv", show_col_types = FALSE)
zs <- read_csv("outputs/analysis/zoning_summary.csv", show_col_types = FALSE)
use_short <- c("Prepared Food Shop" = "Prepared food shop", "Take-Out Restaurant" = "Take-out restaurant",
               "Sit-Down Restaurant" = "Sit-down restaurant",
               "Nightclubs and Public Entertainment Venue" = "Nightclub / public entertainment",
               "Assembly and Entertainment (general)" = "Assembly & entertainment",
               "Event Assembly Facility" = "Event assembly facility",
               "Visitor Accommodations" = "Visitor accommodations (hotel)",
               "Fraternal Organization" = "Fraternal organization")
ord <- c("CMX-5","CMX-4","CMX-3","CMX-2","RMX-3","RM-4","RM-1","SP-PO-A")
in_cw <- unique(st_intersection(zbase, cw)$long_code)   # districts that front Chestnut/Walnut here
pmx <- pm |> mutate(status_if_fronting_chestnut_walnut = if_else(district %in% in_cw, status_if_fronting_chestnut_walnut, base_district_status),
                    use = factor(use_short[use], levels = rev(use_short)),
                    district = factor(district, levels = ord),
                    cell = case_when(base_district_status == "Y" & status_if_fronting_chestnut_walnut == "S" ~ "Y / S*",
                                     TRUE ~ base_district_status),
                    tone = case_when(base_district_status == "N" ~ "N",
                                     base_district_status == "S" ~ "S",
                                     cell == "Y / S*" ~ "YS", TRUE ~ "Y"))
tone_col <- c(Y = "#a9e3cb", YS = "#f7c3a9", S = "#f19a74", N = "#d9d8d3")
dl <- setNames(paste0(ord, "\n", round(zs$pct_of_zoned_land[match(ord, zs$zoning_district)]), "%"), ord)
p2 <- ggplot(pmx, aes(district, use)) +
  geom_tile(aes(fill = tone), colour = surf, linewidth = 1.2) +
  geom_text(aes(label = cell), size = 2.7, colour = ink, fontface = "bold") +
  scale_fill_manual(values = tone_col, guide = "none") +
  scale_x_discrete(position = "top", labels = dl) +
  labs(title = "Figure 2. Nighttime use permission matrix",
       subtitle = "Y = by right · S = special exception · N = not allowed / not listed (prohibited)\nY / S* = by right in base district, but special exception on lots fronting Chestnut or Walnut St\n(Table 14-502-2; shown only for districts that front those streets here). % = share of zoned land.",
       caption = "Phila. Code §14-602 Tables 14-602-1, -2, -4; §14-502(5) Table 14-502-2 (amlegal, accessed Oct 2026). \nRMX-3: commercial uses ≤25% of GFA. SP-PO-A: food service only if co-located with, and smaller than, a park use.",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 8.5) +
  theme(panel.grid = element_blank(), axis.text = element_text(colour = ink2),
        axis.text.x.top = element_text(face = "bold", colour = ink, lineheight = 0.9),
        plot.title = element_text(face = "bold", colour = ink, size = 10.5),
        plot.subtitle = element_text(colour = ink2, size = 7.5),
        plot.caption = element_text(colour = muted, size = 6.3, hjust = 0),
        plot.title.position = "plot", plot.caption.position = "plot",
        plot.background = element_rect(fill = surf, colour = NA))
ggsave("outputs/figures/permission_matrix.png", p2, width = 6.2, height = 3.5, dpi = 300, bg = surf)

# ---- licensing_zoning_summary.png (Figure 3) ------------------------------
cmp <- read_csv("outputs/analysis/licensing_zoning_comparison.csv", show_col_types = FALSE)
ev_lab <- function(v) case_when(grepl("approval verified", v) ~ "Approval found (scope matches)",
                                grepl("address-level", v) ~ "Address-level approval only",
                                grepl("no approval found", v) ~ "No approval found in records",
                                TRUE ~ NA_character_)
s3 <- cmp |> mutate(cls = factor(cls_lab[regulatory_classification], levels = rev(cls_lab)),
                    liq = if_else(category == "Food service, no liquor licence", "Food service only", "Liquor-licensed"),
                    liq = factor(liq, levels = c("Liquor-licensed", "Food service only"))) |>
  count(cls, liq)
tot <- s3 |> group_by(cls) |> summarise(n = sum(n))
p3 <- ggplot(s3, aes(n, cls, fill = liq)) +
  geom_col(width = 0.62, colour = surf, linewidth = 0.6) +
  geom_text(data = tot, aes(n, cls, label = paste0(n, " (", round(100 * n / sum(tot$n)), "%)")), inherit.aes = FALSE,
            hjust = -0.15, size = 2.8, colour = ink) +
  scale_fill_manual(values = c("Liquor-licensed" = "#2a78d6", "Food service only" = "#86b6ef"), name = NULL) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.18))) +
  labs(title = "Figure 3. Establishments by regulatory classification (n = 63)",
       subtitle = "Denominator: identifiable establishments with a current relevant licence.\nLiquor-licensed = PLCB restaurant, hotel or catering-club licence.",
       x = "Establishments", y = NULL) +
  theme_minimal(base_size = 8.5) +
  theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
        panel.grid.major.x = element_line(colour = "#e7e6e2", linewidth = 0.3),
        axis.text = element_text(colour = ink2), legend.position = "top", legend.justification = "left",
        plot.title = element_text(face = "bold", colour = ink, size = 10.5),
        plot.subtitle = element_text(colour = ink2, size = 7.3),
        plot.title.position = "plot", plot.caption.position = "plot",
        plot.background = element_rect(fill = surf, colour = NA))
ggsave("outputs/figures/licensing_zoning_summary.png", p3, width = 6.2, height = 2.6, dpi = 300, bg = surf)
