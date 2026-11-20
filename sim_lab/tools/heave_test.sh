#!/usr/bin/env bash
export LC_ALL=C
# Bir dunyayi pencere acmadan calistirir; SIMULASYON zamani (ts), gercek zaman
# carpani (rtf), z / roll / pitch yazar, sonra Gazebo'yu kapatir.
# Kullanim (sim_lab klasorunde, VRX source edilmis olarak):
#   bash tools/heave_test.sh worlds/fixed_flat.sdf [sure_saniye]
W="$1"; T="${2:-20}"
[ -f "$W" ] || { echo "Dunya dosyasi yok: $W"; exit 1; }
WN=$(grep -o '<world name="[^"]*"' "$W" | head -1 | cut -d'"' -f2)
export GZ_SIM_RESOURCE_PATH="$PWD/models:$GZ_SIM_RESOURCE_PATH"
pkill -f "gz sim" 2>/dev/null; sleep 1
gz sim -s "$W" > /tmp/heave_gz.log 2>&1 &      # duraklatilmis baslar
sleep 4
gz service -s /world/$WN/control --reqtype gz.msgs.WorldControl \
  --reptype gz.msgs.Boolean --timeout 3000 --req 'pause: false' > /dev/null
echo "dunya: $W"
echo "  ts(s)   rtf      z     roll    pitch"
start=$SECONDS
while [ $((SECONDS-start)) -lt "$T" ]; do
  st=$(gz topic -e -t /world/$WN/stats -n 1 2>/dev/null | awk '
      /^sim_time/{f=1} f&&/^ *sec:/{s=$2} f&&/^ *nsec:/{n=$2; f=0}
      /^real_time_factor/{r=$2} END{printf "%7.2f %5.2f", s+n/1e9, r}')
  gz model -m boat -p 2>/dev/null | grep -A2 Pose | tail -2 | tr -d '[]' | tr '\n' ' ' \
    | awk -v st="$st" '{printf "%s %7.3f %7.3f %7.3f\n", st, $3, $4, $5}'
  sleep 0.1
done
pkill -f "gz sim"
echo "--- Gazebo hata satirlari (yoksa bos):"
grep -iE "error|fail|\[Err\]" /tmp/heave_gz.log | head -5
