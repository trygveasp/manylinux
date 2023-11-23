	 
#!/bin/bash
#
# Launch epy_what.py with arpifs libraries available and loop
# until all unresolved routines have added to the dummies
#

EPY_PATH=/data/EPyGrAM-1.4.9/
export PATH=/opt/python/cp38-cp38/bin/:$PATH
export PYTHONPATH=$PYTHONPATH:${EPY_PATH}:${EPY_PATH}/site:${EPY_PATH}/epygram
export PATH=/opt/rh/devtoolset-10/root/usr/bin/:${EPY_PATH}/apptools:$PATH
gcc=gcc
#export PATH=${EPY_PATH}/apptools:$PATH
# gcc=/usr/bin/gcc
pip install six numpy matplotlib netCDF4 h5py eccodes

arpifs4py=${EPY_PATH}/site/arpifs4py/libs4py.so 
Stat2shared=/data/Stat2shared
wrk=/data/libs4py

mkdir -p $wrk
cd $wrk

cat > dummies.c << EOF
#include <stdio.h>
#include <stdlib.h>
static void msg(const char *routine)
{
  fprintf(stderr,"Error: Should not be calling the dummy routine '%s'\n", routine);
}

void init_gfortran_big_endian_(){
  _gfortran_set_convert (2);
}
void init_gfortran_native_endian_(){
  _gfortran_set_convert (0);
}

EOF
set -x

$gcc --version
$gcc -fpic -c dummies.c || exit 1
rm -f $arpifs4py
rm -f libs4py.so
$Stat2shared $arpifs4py

epy_what.py

M=$( epy_what.py 2>&1 | head -1 | cut -d" " -f13 )
M=`echo $M | sed -e "s#).##g"`
while [ $M != "" ] ; do
  echo "void $M() { msg(\"$M\"); }" >> dummies.c
  $gcc -fpic -c dummies.c
  $Stat2shared $arpifs4py || exit 1
  M=$( epy_what.py 2>&1 | head -1 | cut -d" " -f13 )
  M=`echo $M | sed -e "s#).##g"`
done

