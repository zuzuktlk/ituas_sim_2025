# sim_lab: BeeQueen Gazebo simülasyonu düzeltme çalışması

Takımın modeline dokunmadan, aynı fizik ayarlarıyla ölçüm yapıp
adım adım düzeltmek için ayrı çalışma klasörü.

## İçerik
- `models/beequeen_asis/`: takımın `models/boat` modelinin kopyası. Fizik aynen korundu;
  sadece `/home/jetson/...` çizim yolları `model://` yapıldı.
- `models/beequeen_fixed/`: düzeltilmiş model (v1), ayrıntılar aşağıda.
- `worlds/baseline_flat.sdf`: `final_boat_hydro.sdf` ile aynı fizik
  (DART, 4 ms, uniform buoyancy); parkur ve sensör sistemi çıkarıldı, düz su.
- `worlds/fixed_flat.sdf`: aynı dünya; kaldırma graded modda, tekne `beequeen_fixed`.
- `tools/hull_hydrostatics.py`: STL gövdeden su çekimi / kaldırma merkezi hesabı.

## Çalıştırma (ROS 2 Jazzy + Gazebo Harmonic + VRX)
    source ~/vrx_ws/install/setup.bash
    cd sim_lab
    export GZ_SIM_RESOURCE_PATH=$PWD/models:$GZ_SIM_RESOURCE_PATH
    gz sim -r worlds/baseline_flat.sdf     # önce (takımın modeli)
    gz sim -r worlds/fixed_flat.sdf        # sonra (v1)

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
  ölçeksiz çizime göre kurulmuş. `meshes/robot.stl` (mm) gövdenin
  1207.75 x 782.1 mm olduğunu gösteriyor: doğru ölçek 1.
- Ağırlık merkezi z = -0.485 m: omurganın (-0.33 m) bile altında.
- Ek kütle sıfır; sönüm katsayıları yuvarlak sayılar; itki sınırı yok.

## Hidrostatik hedef (STL'den, ölçek 1, 30 kg, tatlı su)
    python3 tools/hull_hydrostatics.py models/beequeen_fixed/meshes/stl/denemeas.003.stl --mass 30
- Su hattı base_link z = -0.188 m, omurga -0.332 m → **su çekimi ≈ 14.3 cm**
- Kaldırma merkezi (x, y, z) = (-0.013, -0.006, -0.243) m
- Su hattı alanı ≈ 0.33 m² → 1 kg ek yük ≈ 0.3 cm batma
- Not: STL tam kapalı değil (~%3 açık kenar); ±1–2 cm pay.

## beequeen_fixed v1: ne değişti
| | asis | fixed v1 | Kaynak |
|---|---|---|---|
| Toplam kütle | 101.4 kg | 30 kg | Takım bilgisi (≈30 kg), **tartılınca güncellenecek** |
| Ağırlık merkezi | (0.12, 0, -0.485) | (-0.013, -0.006, -0.05) | x,y: kaldırma merkezi; z: **tahmin** |
| Atalet | 0.57 / 1.04 / 1.54 | 2.34 / 2.50 / 3.03 kg·m² | Jirasyon yarıçapı **tahmini** |
| Kaldırma | uniform + VRX Surface | Yalnızca graded buoyancy | Tek kaynak, su yüzeyini biliyor |
| Ponton şekli | 2 kutu 1.15x0.22x0.20 | Ponton başına 4 katmanlı kutu | STL'nin V kesitine katman hacmiyle uydurma |
| Çizim ölçeği | 2 | 1 | robot.stl (mm) |
| Motor konumu | (-0.3, ±0.33, -0.15) su üstü | (-0.43, +0.25/-0.27, -0.37) | STL'deki kıç bağlantıları, **tahmin** |
| Sönüm, itki | takımın | takımın (değişmedi) | G5'te ele alınacak |

Beklenen (1 serbestlik dereceli hesap): bırakılınca ~1.5 s içinde durulur,
model z ≈ 0.193 m (katman kutuları V kesiti tam izlemediği için STL değerinden ~5 mm farklı).

## Sıradaki
- fixed v1 ölçümü: denge z, durulma süresi, trim.
- G5: ek kütle, sönüm, itki eğrisi ve sınırları; hız ve dönüş testleri.
- Gerçek kütle ve ağırlık merkezi (CAD / tartı) gelince tahminleri güncelle.
