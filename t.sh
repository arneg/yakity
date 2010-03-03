#!/bin/tcsh
#
foreach file (`find $1`)
	echo "sed s/yakity/Yakity/ $file > $file"
	sed s/yakity/Yakity/ $file > $file
end
