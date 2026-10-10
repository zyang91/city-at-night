library(tidyverse)
library(sf)

dat<- st_read("data/studyAreas2026.geojson") 

dat<- dat%>%
  filter(Name == "RITTENHOUSE SQUARE")
