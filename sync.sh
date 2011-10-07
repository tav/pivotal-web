#! /bin/sh

# Public Domain (-) 2011 The Pivotal Web Authors.
# See the Pivotal Web UNLICENSE file for details.

rm -rf gzipped
mkdir -p gzipped

for i in `ls static`; do
	gzip <static/$i >gzipped/$i
done

s3cmd -v -P -M --add-header "Content-Encoding: gzip" sync --delete-removed gzipped/ s3://$S3_BUCKET/