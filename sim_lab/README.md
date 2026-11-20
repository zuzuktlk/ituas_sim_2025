# sim_lab: BeeQueen Gazebo simülasyonu düzeltme çalışması

Takımın modeline dokunmadan, aynı fizik ayarlarıyla ölçüm yapıp
adım adım düzeltmek için ayrı çalışma klasörü.

## İçerik
- `models/beequeen_asis/`: takımın `models/boat` modelinin kopyası. Fizik aynen korundu;
  sadece `/home/jetson/...` çizim yolları `model://` yapıldı.
- `models/beequeen_fixed/`: düzeltilmiş model (v3), ayrıntılar aşağıda.
- `worlds/baseline_flat.sdf`: `final_boat_hydro.sdf` ile aynı fizik
  (DART, 4 ms, uniform buoyancy); parkur ve sensör sistemi çıkarıldı, düz su.
- `worlds/fixed_flat.sdf`: aynı fizik; dünyada kaldırma eklentisi yok, tekne `beequeen_fixed` (v2).
- `tools/hull_hydrostatics.py`: STL gövdeden su çekimi / kaldırma merkezi hesabı.

## Çalıştırma (ROS 2 Jazzy + Gazebo Harmonic + VRX)
    source ~/vrx_ws/install/setup.bash
    cd sim_lab
    export GZ_SIM_RESOURCE_PATH=$PWD/models:$GZ_SIM_RESOURCE_PATH
    gz sim -r worlds/baseline_flat.sdf     # önce (takımın modeli)
    gz sim -r worlds/fixed_flat.sdf        # sonra (v2)

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

## beequeen_fixed: ne değişti (v3)
| | asis | fixed v3 | Kaynak |
|---|---|---|---|
| Toplam kütle | 101.4 kg | 30 kg | Takım bilgisi (≈30 kg), **tartılınca güncellenecek** |
| Ağırlık merkezi (toplam) | (0.12, 0, -0.485) | (-0.013, -0.006, -0.074) | x,y: kaldırma merkezi (motorlar dahil); z: **tahmin** |
| Atalet | 0.57 / 1.04 / 1.54 | 2.34 / 2.50 / 3.03 kg·m² | Jirasyon yarıçapı **tahmini** |
| Kaldırma | uniform + VRX Surface | Yalnızca VRX Surface: ponton başına 4 nokta, r = 0.13 m, nokta z = -0.268 | Tek kaynak; z, STL'nin 30 kg su hattını verecek şekilde seçildi |
| Çarpışma kutuları | 2 kutu 1.15x0.22x0.20 | Ponton başına 4 katmanlı kutu | STL'nin V kesitine uydurma; v2'de sadece temas için |
| Çizim ölçeği | 2 | 1 | robot.stl (mm) |
| Motor konumu | (-0.3, ±0.33, -0.15) su üstü | (-0.43, +0.25/-0.27, -0.37) | STL'deki kıç bağlantıları, **tahmin** |
| Sönüm, itki | takımın | takımın (değişmedi) | G5'te ele alınacak |

### Sürüm geçmişi
- **v1** (graded buoyancy + katman kutuları): tekne 0.35 m'den bırakılınca kıçı üzerinden
  ~128° dönüp ters yüzdü (z = -0.08). El hesabı dengeli olması gerektiğini söylüyor;
  nedeni henüz belirlenmedi (düşüş darbesi mi, eklentinin eğik kutudaki davranışı mı).
  Gazebo'nun kendi graded_buoyancy.sdf örneğinde de sönümsüz küp yuvarlanıp sıçradı.
- **v2** (VRX Surface): VRX'in WAM-V için kullandığı yöntem; kuvvet her noktada uygulanır.
  Görünmeyen varsayılan dalga yüzünden ~5 s'lik salınım (yukarıdaki bölüm).
- **v3**: v2 + dalga gain = 0 (düz su).
  Bilinen sapma: daire kesiti V kesitten geniş, su hattı genişliği ~1.6 kat → yalpa ve
  baş-kıç sertliği gerçekten yüksek olabilir.

Beklenen (heave+pitch+roll düzlem hesabı, sönüm takımın değerleri):
0.30 m'den bırakılınca ~1.5 s'de durulur, **model z ≈ 0.189 m**, trim ≈ 0°.
15° yalpa + 15° baş-kıç bozulmasından ~2 s'de toparlanır.

## Kök neden: görünmeyen dalgalar (v3 ile çözüldü — Gazebo: z = 0.1886 m, ~1.1 s durulma)
v2'de tekne düz suda ~5 s periyotla ±0.3 m inip çıkıyordu. Sistematik eleme
(`diag_*` dünyaları, `tools/odom_log.sh` ile 30 Hz kayıt):

| Test | Sonuç |
|---|---|
| Su eklentisi yok | Serbest düşüş doğru (g) |
| Yalnız sönüm | Limit hız 1.495 m/s (hesap 1.47) — doğru |
| Yalnız Surface | Kuvvet büyüklüğü doğru ama sönümsüz kaotik hareket |
| Zaman adımı 1 ms, motorsuz, ek kütle 0, kütle merkezi orijinde, gz Hydrodynamics | Hiçbiri değiştirmedi |
| VRX'in kendi `roboboat01` modeli | Aynı ~5 s'lik hareket → sorun bizim modelde değil |

Neden: VRX `Surface` eklentisi `<wavefield>` verilmezse **varsayılan PMS dalgası**
üretir (gain 1.0, periyot 5 s, üç bileşen genliği 0.12/0.13/0.13 m, 2 s'de devreye
girer). Dünyadaki su görseli düz olduğu için dalga görünmez. Bu dalgayı kendi
basit modelimize ekleyince Gazebo kaydı 3. ondalığa kadar tutuyor
(ör. t = 5.0 s: Gazebo 0.500, model 0.500).

Çözüm (v3): her Surface eklentisine `<wavefield><wave><gain>0.0</gain>...` eklendi.
Takımın modelinde de aynı durum var: oradaki "zıplama"nın bir kısmı da bu görünmeyen dalga.

Ek bulgu: takımın modeli VRX'in `roboboat01` örnek teknesinin kopyası
(aynı atalet 0.567/1.042/1.542, aynı ponton kutuları); kütle 10→99.2 kg, sönüm ×10,
gövde çizimi BeeQueen ile değiştirilip ×2 büyütülmüş.

## Sıradaki
- fixed v3 ölçümü: denge z, durulma süresi, trim. (İsteğe bağlı: v1 takla nedenini ayırmak için su hattından bırakma testi.)
- G5: ek kütle, sönüm, itki eğrisi ve sınırları; hız ve dönüş testleri.
- Gerçek kütle ve ağırlık merkezi (CAD / tartı) gelince tahminleri güncelle.
