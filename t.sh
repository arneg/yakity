#!/bin/tcsh
#
foreach file (`ls $1`)
	echo "sed s/yakity/Yakity/ $file > $file"
	sed s/yakity/Yakity/ $file > $file
end
