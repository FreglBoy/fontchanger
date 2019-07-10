#!/system/bin/sh
# Advanced Charging Controller (acc) Initializer
# Copyright (c) 2017-2019, VR25 (xda-developers)
# License: GPLv3+


if ! which busybox > /dev/null; then
  if [ -d /sbin/.magisk/busybox ]; then
    PATH=/sbin/.magisk/busybox:$PATH
  elif [ -d /sbin/.core/busybox ]; then
    PATH=/sbin/.core/busybox:$PATH
  else
    exit 3
  fi
fi

modId=$(sed -n 's/^id=//p' ${0%/*}/module.prop)

# prepare working directory
([ -d /sbin/.$modId ] && [[ ${1:-x} != -*o* ]] && exit 0
if ! mount -o remount,rw /sbin 2>/dev/null; then
  cp -a /sbin /dev/.sbin
  mount -o bind,rw /dev/.sbin /sbin
fi
mkdir -p /sbin/.$modId
[ -h /sbin/.$modId/$modId ] && rm /sbin/.$modId/$modId \
  || rm -rf /sbin/.$modId/$modId 2>/dev/null
[ ${MAGISK_VER_CODE:-18200} -gt 18100 ] \
  && ln -s ${0%/*} /sbin/.$modId/$modId \
  || cp -a ${0%/*} /sbin/.$modId/$modId
ln -fs /sbin/.$modId/$modId/$modId.sh /sbin/$modId
ln -fs /sbin/.$modId/$modId/${modId}-functions.sh /sbin/${modId}-functions

# generate power supply log
${0%/*}/psl.sh $(sed -n s/versionCode=//p ${0%/*}/module.prop) &

# fix termux's PATH
termuxSu=/data/data/com.termux/files/usr/bin/su
if [ -f $termuxSu ] && grep -q 'PATH=.*/sbin/su' $termuxSu; then
  sed '\|PATH=|s|/sbin/su|/sbin|' $termuxSu > $termuxSu.tmp
  cat $termuxSu.tmp > $termuxSu
  rm $termuxSu.tmp
fi

# exclude charging switches with unknown values
(cd /sys/class/power_supply/
: > /sbin/.$modId/switches
while IFS= read -r file; do
  if [ -f $(echo $file | awk '{print $1}') ]; then
    on=$(echo $file | awk '{print $2}')
    off=$(echo $file | awk '{print $3}')
    file=$(echo $file | awk '{print $1}')
    chmod +r $file 2>/dev/null
    if grep -Eq "^($on|$off)$" $file || ! cat $file; then
      echo "$file $on $off" >> /sbin/.$modId/switches
    fi > /dev/null 2>&1
  fi
done << SWITCHES
$(grep -Ev '#|^$' ${0%/*}/switches.txt)
SWITCHES
)

# start ${modId}d
sleep 30
unset file termuxSu
kill -9 $(pgrep -f /psl.sh) 2>/dev/null
${0%/*}/${modId}d.sh &) &

exit 0
