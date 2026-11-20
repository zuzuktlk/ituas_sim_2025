#!/usr/bin/env bash
export LC_ALL=C
# Teknenin hareketini /odom topic'inden ~30 Hz ile kaydeder (simulasyon zamaniyla).
# Kullanim (sim_lab klasorunde, VRX source edilmis olarak):
#   bash tools/odom_log.sh worlds/fixed_flat.sdf [sure_saniye]
# Cikti: logs/<dunya>_odom.csv  (t, x, y, z, roll, pitch, yaw)
W="$1"; T="${2:-10}"
[ -f "$W" ] || { echo "Dunya dosyasi yok: $W"; exit 1; }
WN=$(grep -o '<world name="[^"]*"' "$W" | head -1 | cut -d'"' -f2)
mkdir -p logs; OUT="logs/${WN}_odom.csv"
export GZ_SIM_RESOURCE_PATH="$PWD/models:$GZ_SIM_RESOURCE_PATH"
pkill -f "gz sim" 2>/dev/null; sleep 1
gz sim -s "$W" > /tmp/odom_gz.log 2>&1 &
sleep 4
( timeout "$((T+1))" gz topic -e -t /odom > /tmp/odom_raw.txt ) &
sleep 0.5
gz service -s /world/$WN/control --reqtype gz.msgs.WorldControl \
  --reptype gz.msgs.Boolean --timeout 3000 --req 'pause: false' > /dev/null
sleep "$((T+1))"
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
' /tmp/odom_raw.txt | sort -t, -k1,1n -u > "$OUT.tmp"
{ echo "t,x,y,z,roll,pitch,yaw"; cat "$OUT.tmp"; } > "$OUT"; rm -f "$OUT.tmp"
n=$(($(wc -l < "$OUT")-1))
echo "kayit: $OUT  ($n satir)"
[ "$n" -gt 0 ] && { head -4 "$OUT"; echo ...; tail -3 "$OUT"; } || { echo "Bos! /tmp/odom_raw.txt ilk satirlar:"; head -30 /tmp/odom_raw.txt; }
grep -iE "error|fail|\[Err\]" /tmp/odom_gz.log | head -3
