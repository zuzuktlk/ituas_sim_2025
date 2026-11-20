#!/usr/bin/env bash
export LC_ALL=C
# Tekneyi suda durultup sonra iki motora sabit itki verir; hareketi /odom'dan kaydeder.
# Kullanim (sim_lab klasorunde, VRX source edilmis olarak):
#   bash tools/thrust_test.sh worlds/fixed_flat.sdf SOL_N SAG_N [itki_suresi_s] [durus_suresi_s]
# durus_suresi_s > 0 ise itki bitince motorlar 0 yapilir ve tekne o kadar sure serbest suzulur (durma testi).
# Takim wiki'sine gore NEGATIF deger = ILERI.  Ornek: ... -40 -40 15
# Cikti: logs/<dunya>_thrust_<sol>_<sag>.csv  (t, x, y, z, roll, pitch, yaw)
W="$1"; L="${2:--40}"; R="${3:--40}"; T="${4:-15}"; S="${5:-0}"
[ -f "$W" ] || { echo "Dunya dosyasi yok: $W"; exit 1; }
WN=$(grep -o '<world name="[^"]*"' "$W" | head -1 | cut -d'"' -f2)
mkdir -p logs; OUT="logs/${WN}_thrust_${L}_${R}.csv"; [ "$S" != "0" ] && OUT="logs/${WN}_thrust_${L}_${R}_stop${S}.csv"
export GZ_SIM_RESOURCE_PATH="$PWD/models:$GZ_SIM_RESOURCE_PATH"
pkill -f "gz sim" 2>/dev/null; sleep 1
gz sim -s "$W" > /tmp/thrust_gz.log 2>&1 &
sleep 4
TOT=$((T+S+3))
( timeout "$((TOT+1))" gz topic -e -t /odom > /tmp/thrust_raw.txt ) &
sleep 0.5
gz service -s /world/$WN/control --reqtype gz.msgs.WorldControl \
  --reptype gz.msgs.Boolean --timeout 3000 --req 'pause: false' > /dev/null
sleep 2   # once suda durulsun
echo "itki basliyor: sol=$L N, sag=$R N, $T s"
end=$((SECONDS+T))
while [ $SECONDS -lt $end ]; do
  # iki motor AYNI ANDA (paralel) gonderilir; sirayla gondermek sag motoru ~1 s geciktiriyordu
  gz topic -t /model/boat/joint/leftmotor_link_joint/cmd_thrust  -m gz.msgs.Double -p "data: $L" &
  gz topic -t /model/boat/joint/rightmotor_link_joint/cmd_thrust -m gz.msgs.Double -p "data: $R" &
  wait
  sleep 0.2
done
if [ "$S" != "0" ]; then
  echo "motorlar durdu, $S s serbest suzulme"
  gz topic -t /model/boat/joint/leftmotor_link_joint/cmd_thrust  -m gz.msgs.Double -p "data: 0" &
  gz topic -t /model/boat/joint/rightmotor_link_joint/cmd_thrust -m gz.msgs.Double -p "data: 0" &
  wait
  sleep "$S"
fi
sleep 1.5
pkill -f "gz sim"
awk '
  /^header \{/ {sec=0;nsec=0;px=0;py=0;pz=0;qx=0;qy=0;qz=0;qw=1}
  /stamp \{/ {m="st"} /position \{/ {m="p"} /orientation \{/ {m="o"}
  /^twist \{/ { if (have) {
      r=atan2(2*(qw*qx+qy*qz),1-2*(qx*qx+qy*qy)); s=2*(qw*qy-qz*qx); if(s>1)s=1; if(s<-1)s=-1
      p=atan2(s,sqrt(1-s*s)); y=atan2(2*(qw*qz+qx*qy),1-2*(qy*qy+qz*qz))
      printf "%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n", sec+nsec/1e9,px,py,pz,r,p,y }
      m=""; have=0 }
  m=="st" && $1=="sec:" {sec=$2} m=="st" && $1=="nsec:" {nsec=$2; m=""}
  m=="p" && $1=="x:" {px=$2;have=1} m=="p" && $1=="y:" {py=$2;have=1} m=="p" && $1=="z:" {pz=$2;have=1}
  m=="o" && $1=="x:" {qx=$2} m=="o" && $1=="y:" {qy=$2} m=="o" && $1=="z:" {qz=$2} m=="o" && $1=="w:" {qw=$2}
' /tmp/thrust_raw.txt | sort -t, -k1,1n -u > "$OUT.tmp"
{ echo "t,x,y,z,roll,pitch,yaw"; cat "$OUT.tmp"; } > "$OUT"; rm -f "$OUT.tmp"
n=$(($(wc -l < "$OUT")-1)); echo "kayit: $OUT  ($n satir)"
tail -3 "$OUT"
grep -iE "error|fail|\[Err\]" /tmp/thrust_gz.log | head -3
