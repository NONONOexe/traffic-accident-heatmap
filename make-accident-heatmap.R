# 本票データのダウンロード
library(fs)
if (!dir_exists("data")) dir_create("data")
download.file("https://www.npa.go.jp/publications/statistics/koutsuu/opendata/2019/honhyo_2019.csv", "data/main-data-2019.csv")
download.file("https://www.npa.go.jp/publications/statistics/koutsuu/opendata/2020/honhyo_2020.csv", "data/main-data-2020.csv")
download.file("https://www.npa.go.jp/publications/statistics/koutsuu/opendata/2021/honhyo_2021.csv", "data/main-data-2021.csv")

# データの読み込み
library(tidyverse)
accidents <- bind_rows(
  read_csv("data/main-data-2019.csv", locale = locale(encoding = "Shift_JIS"), col_types = cols(.default = col_character())),
  read_csv("data/main-data-2020.csv", locale = locale(encoding = "Shift_JIS"), col_types = cols(.default = col_character())),
  read_csv("data/main-data-2021.csv", locale = locale(encoding = "Shift_JIS"), col_types = cols(.default = col_character()))
)

# 緯度・経度をDMS形式からDEG形式に変換
library(celestial)
accidents_converted_deg <- accidents |>
  # 項目名の変更
  rename(
    lat_dms = `地点　緯度（北緯）`,
    lon_dms = `地点　経度（東経）`,
  ) |>
  # 度・分・秒を分割
  mutate(
    lat_d   = str_sub(lat_dms, 1, 2),
    lat_m   = str_sub(lat_dms, 3, 4),
    lat_s   = str_c(str_sub(lat_dms, 5, 6), ".", str_sub(lat_dms, 7)),
    lon_d   = str_sub(lon_dms, 1, 3),
    lon_m   = str_sub(lon_dms, 4, 5),
    lon_s   = str_c(str_sub(lon_dms, 6, 7), ".", str_sub(lon_dms, 8))
  ) |> 
  # 変換不可能なデータを除外
  filter(
    0 <= lat_m & lat_m < 60,
    0 <= lat_s & lat_s < 60,
    0 <= lon_m & lon_m < 60,
    0 <= lon_s & lon_s < 60
  ) |>
  # DEG形式に変換
  mutate(
    lat = dms2deg(lat_d, lat_m, lat_s),
    lon = dms2deg(lon_d, lon_m, lon_s)
  )

# sfオブジェクトへ変換
library(sf)
accidents_sf <- accidents_converted_deg |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326)

# 標準地域メッシュの作成
library(jpmesh)
pref_code <- 23
grid_squares <- administration_mesh(pref_code, 1)

# 事故件数をメッシュごとに算出(一時的に非空間データに変換)
accident_counts_sf <-
  st_join(accidents_sf, grid_squares) |>
  st_drop_geometry() |>
  group_by(meshcode) |>
  summarise(count = n()) |>
  inner_join(grid_squares, by = "meshcode") |>
  st_as_sf()

library(tmap)
tmap_mode("view")

# 交通事故件数のレイヤを作成
accident_counts_tm <- tm_shape(accident_counts_sf) +
  tm_polygons(
    col        = "count",
    alpha      = 0.8,
    title      = "事故件数 (件)",
    border.col = "gray",
    id         = "meshcode",
    popup.vars = c("事故件数" = "count"))

# 行政区域のレイヤーの作成
library(jpndistrict)
cities_tm <-
  tm_shape(jpn_cities(pref_code)) +
  tm_polygons(
    col   = "white",
    alpha = 0.5,
    id    = "city")

# 死亡事故地点のレイヤーの作成
fatal_accidents_tm <-
  accidents_sf |>
  st_filter(grid_squares) |>
  filter(0 < as.integer(死者数)) |>
  select(!c(
    lat_dms, lon_dms,
    lat_d, lat_m, lat_s,
    lon_d, lon_m, lon_s)) |>
  tm_shape() +
  tm_dots(col        = "royalblue",
          border.col = "transparent",
          id         = "fatal_accidents")

map <- cities_tm + accident_counts_tm + fatal_accidents_tm
tmap_save(map, "index.html")
