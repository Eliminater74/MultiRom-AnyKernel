# AnyKernel2 Ramdisk Mod Script 
# osm0sis @ xda-developers
# Mod 4 LG G3 By Eliminater74

## AnyKernel setup
# EDIFY properties
kernel.string=Nebula Kernel Rev12.2_LP By Eliminater74
do.devicecheck=1
do.initd=1
do.modules=0
device.name1=d851
device.name2=LG-d851
device.name2=LG-D851
device.name3=LG
device.name4=LGE
device.name5=LG G3

# shell variables
block=/dev/block/platform/msm_sdcc.1/by-name/boot;

## end setup


## AnyKernel methods (DO NOT CHANGE)
# set up extracted files and directories
ramdisk=/tmp/anykernel/ramdisk;
bin=/tmp/anykernel/tools;
split_img=/tmp/anykernel/split_img;
patch=/tmp/anykernel/patch;

chmod -R 755 $bin;
mkdir -p $ramdisk $split_img;

OUTFD=/proc/self/fd/$1;
ui_print() { echo -e "ui_print $1\nui_print" > $OUTFD; }

# dump boot and extract ramdisk
dump_boot() {
  dd if=$block of=/tmp/anykernel/boot.img;
  $bin/unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Dumping/splitting image failed. Aborting..."; exit 1;
  fi;
  mv -f $ramdisk /tmp/anykernel/rdtmp;
  mkdir -p $ramdisk;
  cd $ramdisk;
  gunzip -c $split_img/boot.img-ramdisk.gz | cpio -i;
  if [ $? != 0 -o -z "$(ls $ramdisk)" ]; then
    ui_print " "; ui_print "Unpacking ramdisk failed. Aborting..."; exit 1;
  fi;
  cp -af /tmp/anykernel/rdtmp/* $ramdisk;
}

# repack ramdisk then build and write image
write_boot() {
  cd $split_img;
  cmdline=`cat *-cmdline`;
  board=`cat *-board`;
  base=`cat *-base`;
  pagesize=`cat *-pagesize`;
  kerneloff=`cat *-kerneloff`;
  ramdiskoff=`cat *-ramdiskoff`;
  tagsoff=`cat *-tagsoff`;
  if [ -f *-second ]; then
    second=`ls *-second`;
    second="--second $split_img/$second";
    secondoff=`cat *-secondoff`;
    secondoff="--second_offset $secondoff";
  fi;
  if [ -f /tmp/anykernel/zImage ]; then
    kernel=/tmp/anykernel/zImage;
  else
    kernel=`ls *-zImage`;
    kernel=$split_img/$kernel;
  fi;
  if [ -f /tmp/anykernel/dtb ]; then
    dtb="--dt /tmp/anykernel/dtb";
  elif [ -f *-dtb ]; then
    dtb=`ls *-dtb`;
    dtb="--dt $split_img/$dtb";
  fi;
  cd $ramdisk;
  find . | cpio -H newc -o | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Repacking ramdisk failed. Aborting..."; exit 1;
  fi;
  $bin/mkbootimg --kernel $kernel --ramdisk /tmp/anykernel/ramdisk-new.cpio.gz $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset $tagsoff $dtb --output /tmp/anykernel/boot-new.img;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Repacking image failed. Aborting..."; exit 1;
  elif [ `wc -c < /tmp/anykernel/boot-new.img` -gt `wc -c < /tmp/anykernel/boot.img` ]; then
    ui_print " "; ui_print "New image larger than boot partition. Aborting..."; exit 1;
  fi;
  if [ -f "/data/custom_boot_image_patch.sh" ]; then
    ash /data/custom_boot_image_patch.sh /tmp/anykernel/boot-new.img;
    if [ $? != 0 ]; then
      ui_print " "; ui_print "User script execution failed. Aborting..."; exit 1;
    fi;
  fi;
  
# Bump Image #
  dd if=$bin/bump bs=1 count=32 >> /tmp/anykernel/boot-new.img;
  dd if=/dev/zero of=$block;
  dd if=/tmp/anykernel/boot-new.img of=$block;
}

# backup_file <file>
backup_file() { cp $1 $1~; }

# replace_string <file> <if search string> <original string> <replacement string>
replace_string() {
  if [ -z "$(grep "$2" $1)" ]; then
      sed -i "s;${3};${4};" $1;
  fi;
}

# replace_section <file> <begin search string> <end search string> <replacement string>
replace_section() {
  line=`grep -n "$2" $1 | cut -d: -f1`;
  sed -i "/${2}/,/${3}/d" $1;
  sed -i "${line}s;^;${4}\n;" $1;
}

# remove_section <file> <begin search string> <end search string>
remove_section() {
  sed -i "/${2}/,/${3}/d" $1;
}

# insert_line <file> <if search string> <before|after> <line match string> <inserted line>
insert_line() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;${5}\n;" $1;
  fi;
}

# replace_line <file> <line replace string> <replacement line>
replace_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | cut -d: -f1`;
    sed -i "${line}s;.*;${3};" $1;
  fi;
}

# remove_line <file> <line match string>
remove_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | cut -d: -f1`;
    sed -i "${line}d" $1;
  fi;
}

# prepend_file <file> <if search string> <patch file>
prepend_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

# insert_file <file> <if search string> <before|after> <line match string> <patch file>
insert_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;\n;" $1;
    sed -i "$((line - 1))r $patch/$5" $1;
  fi;
}

# append_file <file> <if search string> <patch file>
append_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo -ne "\n" >> $1;
    cat $patch/$3 >> $1;
    echo -ne "\n" >> $1;
  fi;
}

# replace_file <file> <permissions> <patch file>
replace_file() {
  cp -pf $patch/$3 $1;
  chmod $2 $1;
}

# patch_fstab <fstab file> <mount match name> <fs match type> <block|mount|fstype|options|flags> <original string> <replacement string>
patch_fstab() {
  entry=$(grep "$2" $1 | grep "$3");
  if [ -z "$(echo "$entry" | grep "$6")" ]; then
    case $4 in
      block) part=$(echo "$entry" | awk '{ print $1 }');;
      mount) part=$(echo "$entry" | awk '{ print $2 }');;
      fstype) part=$(echo "$entry" | awk '{ print $3 }');;
      options) part=$(echo "$entry" | awk '{ print $4 }');;
      flags) part=$(echo "$entry" | awk '{ print $5 }');;
    esac;
    newentry=$(echo "$entry" | sed "s;${part};${6};");
    sed -i "s;${entry};${newentry};" $1;
  fi;
}

## end methods


## AnyKernel permissions
# set permissions for included files
#chmod -R 755 $ramdisk
# chmod 644 $ramdisk/sbin/media_profiles.xml


## AnyKernel install
dump_boot;

# begin ramdisk changes

## AnyKernel permissions
# set permissions for included files
chmod -R 755 $ramdisk

# set permissions for Synapse
chmod -R 755 $ramdisk
chmod 0755 /system/sbin/uci
chmod 644 $ramdisk/res/synapse/*
chmod -R 755 $ramdisk/res/synapse/actions
chmod -R 777 $ramdisk/res/synapse/files

## AnyKernel install
dump_boot;

## begin ramdisk changes ##

# insert initd scripts
cp -fp $patch/init.d/* $initd
chmod -R 766 $initd

# mpdecsion binary
#mv $bindir/mpdecision-rm $bindir/mpdecision

# adb secure
backup_file default.prop;
replace_string default.prop "ro.adb.secure=0" "ro.adb.secure=1" "ro.adb.secure=0";
replace_string default.prop "ro.secure=0" "ro.secure=1" "ro.secure=0";

# init.g3.rc
backup_file init.g3.rc;
append_file init.g3.rc "nebula-post_boot" init.g3.patch;
append_file init.g3.rc "/sbin/uci" init.g3;

# Disable QCOM Thermal Driver
insert_line init.g3.rc "#Disable QCOM Thermal" after "service thermal-engine /system/bin/thermal-engine" "   #Disable QCOM Thermal\n   disabled\n"


# init.rc ##
#backup_file init.rc
#replace_string init.rc "setprop selinux.reload_policy 1" "setprop selinux.reload_policy 1" "setprop selinux.reload_policy 0";
#replace_string init.rc "mkdir /data/security 0711 system system" "mkdir /data/security 0711 system system" "mkdir /data/security 0755 system system";
#replace_string init.rc "mkdir /data/backup 0700 system system" "mkdir /data/backup 0700 system system" "mkdir /data/backup 0755 system system";
#replace_string init.rc "mkdir /data/media 0770 media_rw media_rw" "mkdir /data/media 0770 media_rw media_rw" "mkdir /data/media 0755 media_rw media_rw";
#replace_string init.rc "mkdir /data/user 0711 system system" "mkdir /data/user 0711 system system" "mkdir /data/user 0755 system system";

# init.superuser.rc
#if [ -f init.superuser.rc ]; then
#  backup_file init.superuser.rc;
#  replace_string init.superuser.rc "Superuser su_daemon" "# su daemon" "\n# Superuser su_daemon";
#  prepend_file init.superuser.rc "SuperSU daemonsu" init.superuser;
#else
#  replace_file init.superuser.rc 750 init.superuser.rc;
#  insert_line init.rc "init.superuser.rc" after "on post-fs-data" "    import /init.superuser.rc\n";
#fi;

# add frandom compatibility
backup_file ueventd.rc;
insert_line ueventd.rc "frandom" after "urandom" "/dev/frandom              0666   root       root\n";
insert_line ueventd.rc "erandom" after "urandom" "/dev/erandom              0666   root       root\n";

backup_file file_contexts;
insert_line file_contexts "frandom" after "urandom" "/dev/frandom				u:object_r:frandom_device:s0\n";
insert_line file_contexts "erandom" after "urandom" "/dev/erandom				u:object_r:erandom_device:s0\n";

# Add F2FS Support for /data and /cache since its can be used on ANY rom
#backup_file fstab.g3
#replace_file fstab.g3 750 fstab.g3;

# xPrivacy
# Thanks to @Shadowghoster & @@laufersteppenwolf
param=$(grep "xprivacy" service_contexts)
if [ -z $param ]; then
    echo -ne "xprivacy453                               u:object_r:system_server_service:s0\n" >> service_contexts
fi

# end ramdisk changes

write_boot;

## end install

