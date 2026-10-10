library(tidyverse)
library(sf)

dat<- st_read("data/studyAreas2026.geojson") 

dat<- dat%>%
  filter(Name == "RITTENHOUSE SQUARE")

bd<- st_read("data/business_improvement_districts.shp")

comercial_corr<- st_read("data/commercial_corridors.geojson")

council_d<- st_read("data/Council_Districts_2024.geojson")

b_dis<- st_read("data/Boundaries_District.geojson")

v_dis<- st_read("data/Vending_Special_Districts.geojson")

z_dis<- st_read("data/Zoning_BaseDistricts.geojson")

z_overlay <- st_read("data/Zoning_Overlays.geojson")

z_rco <- st_read("data/Zoning_RCO.geojson")


# clip based on study area (dat)
b_dis_clip <- st_intersection(b_dis, dat)

bd<- st_transform(bd, crs = st_crs(dat))
bd_clip <- st_intersection(bd, dat)

commercial_corr_clip <- st_intersection(comercial_corr, dat)

council_d_clip <- st_intersection(council_d, dat)

v_dis_clip <- st_intersection(v_dis, dat)

z_dis_clip <- st_intersection(z_dis, dat)

z_overlay_clip <- st_intersection(z_overlay, dat)

z_rco_clip <- st_intersection(z_rco, dat)
