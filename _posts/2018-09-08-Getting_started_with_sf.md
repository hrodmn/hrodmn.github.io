---
title: "Geospatial Analysis in R: getting started with sf"
---

The sf package is the successor to the common suite of geospatial analysis packages for R: sp, rgdal, and rgeos. This is a good thing because sf provides a unified solution to most of the geospatial manipulation and analysis operations that are often used within R. The way you interact with spatial data in the sf is more intuitive than in the past because the structure of the sf class in R is very simple relative to the sp class.

An object of the sf class consists of a normal data.frame with a geometry column that contains the geometry for each feature. That may not sound very exciting, but it makes for a much easier time when manipulating and summarizing spatial data. If you are interested in the history and rationale for implementing the sf package, there are several enlightening blog posts and vignettes on the sf [github page](https://github.com/r-spatial/sf#blogs-presentations-vignettes-sp-sf-wiki).

### Installation

Installing sf can be troublesome at first due to system dependencies, but there are some steps outlined on the package [readme](https://github.com/r-spatial/sf#installing) that seem to work.

``` r
library(tidyverse)
## ── Attaching packages ────────────────────────────────── tidyverse 1.2.1 ──
## ✔ ggplot2 3.0.0     ✔ purrr   0.2.5
## ✔ tibble  1.4.2     ✔ dplyr   0.7.6
## ✔ tidyr   0.8.1     ✔ stringr 1.3.1
## ✔ readr   1.1.1     ✔ forcats 0.3.0
## ── Conflicts ───────────────────────────────────── tidyverse_conflicts() ──
## ✖ dplyr::filter() masks stats::filter()
## ✖ dplyr::lag()    masks stats::lag()
library(sf)
## Linking to GEOS 3.6.1, GDAL 2.2.3, proj.4 5.1.0
library(spData)
```

### Download some data

The ecological supersections make a cool spatial dataset that describe large ecological provinces across the continental US.

``` r
# import supersection shapefile
download.file(url = "https://www.arb.ca.gov/cc/capandtrade/protocols/usforest/2014/supersectionshapefiles/gis-supersection-shape-file.zip",
              destfile = "/tmp/gis-supersection-shape-file.zip")
unzip(zipfile = "/tmp/gis-supersection-shape-file.zip", exdir = "/tmp/super")
superFile <- "/tmp/super/Supersections/Supersections.shp"
```

### Reading in spatial data

The shapefile can be read in using the function `st_read` and projected to EPSG:4326 using the function `st_transform`. Notice that you can use pipes and the tidyverse framework on objects of the `sf` class! `st_read` can also handle alternative file formats such as geojson and GeoPackage (.gpkg).

``` r
supersectionShape <- st_read(dsn = superFile) %>%
  st_transform(crs = 4326)
## Reading layer `Supersections' from data source `/private/tmp/super/Supersections/Supersections.shp' using driver `ESRI Shapefile'
## Simple feature collection with 95 features and 5 fields
## geometry type:  MULTIPOLYGON
## dimension:      XY
## bbox:           xmin: -2355031 ymin: 269687.9 xmax: 2257506 ymax: 3165565
## epsg (SRID):    NA
## proj4string:    +proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-96 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs
```

### Data structure

To understand why sf makes the world a better place, take a look at the class of `supersectionShape`. It's an object of class `sf` and `data.frame`!

``` r
class(supersectionShape)
## [1] "sf"         "data.frame"
```

The `data.frame` structure of an sf object is also very convenient.

``` r
head(supersectionShape)
## Simple feature collection with 6 features and 5 fields
## geometry type:  MULTIPOLYGON
## dimension:      XY
## bbox:           xmin: -123.6016 ymin: 42.08068 xmax: -98.82367 ymax: 48.99998
## epsg (SRID):    4326
## proj4string:    +proj=longlat +datum=WGS84 +no_defs
##          AREA PERIMETER    ACRES                 SSection SS_Name2
## 1 30741682875 1404657.1  7596137        Okanogan Highland     <NA>
## 2 28793819858 1201969.9  7114983       Northwest Cascades     <NA>
## 3 17147017863 3335379.1  4237070             Puget Trough     <NA>
## 4 21883664760  790723.2  5407398 Northern Rocky Mountains     <NA>
## 5 41675060546 1252913.5 10297621    Northern Great Plains     <NA>
## 6 69771019667 2634088.8 17240259           Columbia Basin     <NA>
##                         geometry
## 1 MULTIPOLYGON (((-116.232 48...
## 2 MULTIPOLYGON (((-121.4919 4...
## 3 MULTIPOLYGON (((-122.5824 4...
## 4 MULTIPOLYGON (((-114.798 47...
## 5 MULTIPOLYGON (((-111.5483 4...
## 6 MULTIPOLYGON (((-118.4671 4...
```

### Plotting

sf objects can be plotted using base R plotting methods, but the `ggplot` method creates really nice looking maps with a familiar interface to many users.

``` r
ggplot() +
  geom_sf(data = supersectionShape,
          size = 0.5,
          color = "black",
          alpha = 0) +
  theme_bw() +
  coord_sf() +
  labs(title = "Ecological Supersections",
       subtitle = "Map of the ecological supersections in the continental US",
       caption = "Source: CA ARB")
```

![Map of ecological supersections in continental US](../assets/images/ggplotting-1.svg)
