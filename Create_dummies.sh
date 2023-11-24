	 
#!/bin/bash
#
# Launch epy_what.py with arpifs libraries available and loop
# until all unresolved routines have added to the dummies
#

[ "$EPY_PATH" == "" ] && echo "You must set EPY_PATH" && exit 1
arpifs4py=${EPY_PATH}/site/arpifs4py/libs4py.so 

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

gcc -fpic -c dummies.c || exit 1
rm -f $arpifs4py
ls -l $arpifs4py
rm -f libs4py.so
Stat2shared $arpifs4py

M=$( epy_what.py 2>&1 | sed -n 3p | cut -d" " -f13 )
M=`echo $M | sed -e "s#).##g"`
while [ "$M" != "" ] ; do
  echo "void $M() { msg(\"$M\"); }" >> dummies.c
  gcc -fpic -c dummies.c
  Stat2shared $arpifs4py || exit 1
  M=$( epy_what.py 2>&1 | sed -n 3p | cut -d" " -f13 )
  M=`echo $M | sed -e "s#).##g"`
done

