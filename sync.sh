#! /bin/sh

# Public Domain (-) 2011 The Pivotal Web Authors.
# See the Pivotal Web UNLICENSE file for details.

rm -rf gzipped
mkdir -p gzipped/css
mkdir -p gzipped/js

for i in `ls static/css`; do
	gzip <static/css/$i >gzipped/css/$i
done

for i in `ls static/js`; do
	gzip <static/js/$i >gzipped/js/$i
done

s3cmd -v -P -M --add-header "Content-Encoding: gzip" sync --delete-removed gzipped/css/ s3://$S3_BUCKET/css/
s3cmd -v -P -M --add-header "Content-Encoding: gzip" sync --delete-removed gzipped/js/ s3://$S3_BUCKET/js/
s3cmd -v -P -M sync --delete-removed static/gfx/ s3://$S3_BUCKET/gfx/
