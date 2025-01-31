#!/bin/bash
# Alireza Shafaei - shafaei@cs.ubc.ca - Jan 2016

resolution=4096
density=1200
#colorspace="-depth 8"
colorspace="-colorspace sRGB -background white -alpha remove"
makeWide=true

if [ $# -eq 0 ]; then
    echo "No arguments supplied!"
    echo "Usage: ./pdf2pptx.sh file.pdf"
    echo "			Generates file.pdf.pptx in widescreen format (by default)"
    echo "       ./pdf2pptx.sh file.pdf notwide"
    echo "			Generates file.pdf.pptx in 4:3 format"
    exit 1
fi

if [ $# -eq 2 ]; then
	if [ "$2" == "notwide" ]; then
		makeWide=false
	fi
fi

echo "Doing $1"
tempname="$1.temp"
if [ -d "$tempname" ]; then
	echo "Removing ${tempname}"
	rm -rf "$tempname"
fi

mkdir "$tempname"
#convert -density $density $colorspace -resize "x${resolution}" "$1" "$tempname"/slide.png
pdftoppm -r $density -forcenum -png "$1" "$tempname"/slide

if [ $? -eq 0 ]; then
	echo "Extraction succ!"
else
	echo "Error with extraction"
	exit
fi

if (which perl > /dev/null); then
	# https://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac#comment47931362_1115074
	mypath=$(perl -MCwd=abs_path -le '$file=shift; print abs_path -l $file? readlink($file): $file;' "$0")
elif (which python > /dev/null); then
	# https://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac#comment42284854_1115074
	mypath=$(python -c 'import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))' "$0")
elif (which ruby > /dev/null); then
	mypath=$(ruby -e 'puts File.realpath(ARGV[0])' "$0")
else
	mypath="$0"
fi
mydir=$(dirname "$mypath")

pptname="$1.pptx.base"
fout=$(basename "$1.pptx")
rm -rf "$pptname"
cp -r "$mydir"/template "$pptname"

mkdir "$pptname"/ppt/media

cp "$tempname"/*.png "$pptname/ppt/media/"

function call_sed {
	if [ "$(uname -s)" == "Darwin" ]; then
		sed -i "" "$@"
	else
		sed -i "$@"
	fi
}

function add_slide {
	pat='slide1\.xml\"\/>'
	id=$2
	id=$((id+8))
	entry='<Relationship Id=\"rId'$id'\" Type=\"http:\/\/schemas\.openxmlformats\.org\/officeDocument\/2006\/relationships\/slide\" Target=\"slides\/slide-'$1'\.xml"\/>'
	rep="${pat}${entry}"
	call_sed "s/${pat}/${rep}/g" ../_rels/presentation.xml.rels

	pat='slide1\.xml\" ContentType=\"application\/vnd\.openxmlformats-officedocument\.presentationml\.slide+xml\"\/>'
	entry='<Override PartName=\"\/ppt\/slides\/slide-'$1'\.xml\" ContentType=\"application\/vnd\.openxmlformats-officedocument\.presentationml\.slide+xml\"\/>'
	rep="${pat}${entry}"
	call_sed "s/${pat}/${rep}/g" ../../\[Content_Types\].xml

	sid=$2
	sid=$((sid+256))
	pat='<p:sldIdLst>'
	entry='<p:sldId id=\"'$sid'\" r:id=\"rId'$id'\"\/>'
	rep="${pat}${entry}"
	call_sed "s/${pat}/${rep}/g" ../presentation.xml
}

function make_slide {
	cp ../slides/slide1.xml ../slides/slide-$1.xml
	cat ../slides/_rels/slide1.xml.rels | sed "s/image1\.JPG/slide-${1}.png/g" > ../slides/_rels/slide-$1.xml.rels
	add_slide $1 $2
}

pushd "$pptname"/ppt/media/
count=`ls -ltr | wc -l`
slideNum=0
count=$((count-1))
#for (( slide=$count-1; slide>=1; slide-- ))
for name in `seq -w $count -1 1`;
do
    echo "Processing " "$slideNum" " slide-$name"
    make_slide $name $slideNum
    slideNum=$((slideNum+1))
done

if [ "$makeWide" = true ]; then
	pat='<p:sldSz cx=\"9144000\" cy=\"6858000\" type=\"screen4x3\"\/>'
	wscreen='<p:sldSz cy=\"6858000\" cx=\"12192000\"\/>'
	call_sed "s/${pat}/${wscreen}/g" ../presentation.xml
fi
popd

pushd "$pptname"
rm -rf ../"$fout"
zip -q -r ../"$fout" .
popd

rm -rf "$pptname"
rm -rf "$tempname"
