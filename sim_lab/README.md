# sim_lab: BeeQueen Gazebo simülasyonu düzeltme çalışması

Takımın modeline dokunmadan, aynı fizik ayarlarıyla ölçüm yapıp
adım adım düzeltmek için ayrı çalışma klasörü.

## İçerik
- `models/beequeen_asis/`: takımın `models/boat` modelinin kopyası. Fizik aynen korundu;
  sadece `/home/jetson/...` çizim yolları `model://` yapıldı.
- `worlds/baseline_flat.sdf`: `final_boat_hydro.sdf` ile aynı fizik
  (DART, 4 ms, uniform buoyancy); parkur ve sensör sistemi çıkarıldı, düz su.

## Çalıştırma (ROS 2 Jazzy + Gazebo Harmonic + VRX)
    source ~/vrx_ws/install/setup.bash
    cd sim_lab
    export GZ_SIM_RESOURCE_PATH=$PWD/models:$GZ_SIM_RESOURCE_PATH
    gz sim -r worlds/baseline_flat.sdf

## Baseline ölçümleri (düzeltme öncesi)
| Durum | Sonuç |
|---|---|
| VRX eklentileri yüklenmeden | Tekne sürekli batıyor |
| VRX ile | Dengeye gelmiyor; z ≈ 0.19–0.39 m arası zıplıyor (16–20 s aralık) |
| Havada iniş hızı | ≈ 0.011 m/s (hesap: 1.96 N / zW 200 = 0.0098 m/s) |
| Trim | ≈ 0.023 rad (1.3°) |

## Tespit edilen sorunlar
- Kütle 99.2 kg (gerçek tekne ≈ 30 kg); toplam 101.4 kg, uniform
  kaldırmayı (101.2 kg) dengeleyecek şekilde seçilmiş gibi.
- İki kaldırma kaynağı birden: gz Buoyancy (uniform, su yüzeyini bilmiyor)
  ve VRX Surface.
- Gövde çizimi `<scale>2 2 2</scale>` ile gösteriliyor; fizik şekilleri
  ölçeksiz çizime göre kurulmuş. Görüntü ile fizik uyuşmuyor.
- Ek kütle sıfır; sönüm katsayıları yuvarlak sayılar; itki sınırı yok.

## Sıradaki
`models/beequeen_fixed/`: gerçek kütle, tek kaldırma kaynağı, CAD'den
ponton geometrisi. Ardından aynı ölçümlerle önce/sonra karşılaştırması.
