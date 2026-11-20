# G5: Hareket (itki, hız, dönüş, durma)

## Motor: CubeMars W30 (üretici verisi)
| | Değer |
|---|---|
| İleri itki | 6.7–7.7 kgf (≈ 66–75.5 N) |
| Geri itki | 5.0–5.8 kgf (≈ 49–56.9 N) |
| Nominal güç / akım | 480 W / 22 A |
| Pil | 6S LiPo |
| Ölçü / ağırlık | Ø100×108 mm, havada 420 g, suda 200 g |
| ESC | W30 ESC-6S-45A |

PWM (1100–1900 µs) → Newton eğrisi: **bulamadım**. Gerekirse havuzda kantar ile ölçülür.

## v3 → v4 değişiklikleri (`models/beequeen_fixed/model.sdf`)
| Ne | v3 (takımın değeri) | v4 | Neden |
|---|---|---|---|
| İtki sınırı | yok (±1000 N) | ileri −75.5 N, geri +56.9 N | W30 üst değerleri. Negatif = ileri |
| Motor konumu | (−0.434, +0.248 / −0.271, −0.37) | (−0.420, +0.251 / −0.269, −0.365) | CAD'deki itici merkezleri |
| xU / xUU (ileri sönüm) | 100 / 150 | 4 / 15 | Takımınki ~10–100 kat fazla |
| yV / yVV (yan) | 50 / 100 | 10 / 150 | Yanal alan ~0.29 m², Cd ~1 |
| nR / nRR (dönme) | 30 / 50 | 3 / 6 | Aynı yanal akış, boy boyunca |
| zW, kP, mQ… | aynı | aynı | Yüzme testinde doğrulandı |

**Kanıt:** v3'te 40+40 N ile hız 0.468 m/s çıktı. Takımın sönümü bu hızda ~80 N direnç verir.
Sürtünme hesabı (ITTC-57, ıslak alan 0.862 m²) aynı hızda ~0.5 N verir.

**Yorum (tahmin):** Kısa ve dolgun pontonlarda 1–2 m/s'de dalga direnci sürtünmenin birkaç katı
olabilir; xUU = 15 bu yüzden seçildi. Gerçek değer bilinmiyor; loglarla ayarlanacak.

Logdan ayar formülü (sabit gazda düz gidiş): `xUU ≈ toplam itki / hız²`.

## v4 için beklenen (basit 3 serbestlik derecesi hesabı, `tools/analyze_run.py` ile aynı ölçüm)
| Test | Komut | Beklenen |
|---|---|---|
| Düz, yarım gaz | `-40 -40 15` | ~2.18 m/s |
| Düz, tam gaz | `-75.5 -75.5 15` | ~3.04 m/s |
| Sadece sol motor | `-40 0 15` | ~1.23 m/s, sağa dönüş ~62 °/s, yarıçap ~1.1 m |
| Durma | `-40 -40 15 10` | 2.18 m/s'den 0.1 m/s'ye ~9 s, ~4 m süzülme |

Gazebo bu hesaptan farklı çıkarsa fark şunlardan gelir: baş-kıç eğilmesi, Surface kaldırma
noktaları ve kütle merkezinin ±y kayıklığı. Bu tablo hesabın doğru kurulduğunu kontrol etmek için.

## Bilinen eksikler
- İtki hızla düşmüyor: W30'un değerleri statik (bollard) itki.
- Motor mahfazası 1.0 kg + pervane 0.1 kg; gerçek W30 ise 0.42 kg. Toplam 30 kg korunduğu için değiştirilmedi.
- Ek kütle 0. Daha önce denendi, yüzme davranışını değiştirmedi.

## Gerçek veriyle doğrulama (G7): takımdan istenecek
Pixhawk SD kartındaki `APM/LOGS/*.BIN` (veya `.tlog`, ROS bag) içinde aşağıdakilerden biri:
1. ≥10 s sabit gazda düz gidiş: GPS hızı ve PWM değeri
2. Tek motorla ya da farklı gazla dönüş
3. Gaz kesilip süzülerek durma
