#!/bin/bash

set -e

cd rhymes/
indextmpfile=$(mktemp)
rsstmpfile=$(mktemp)

for file in *; do
    if [[ "$file" == *".txt" ]]; then
        name=$(echo $file | sed -e 's/.txt//' -e 's/_/ /g')
        author=$(git show --format="%aN" $(git blame $file | head -n1 | cut -d" " -f 1) | head -n1)
        date=$(git show --format="%ai" $(git blame $file | head -n1 | cut -d" " -f 1) | head -n1 | cut -d" " -f 1,2 | sed -e 's/ /T/')
        slug=$(echo $file | sed -e 's/.txt//')

        # HTML-escape the poem, then fold it onto a single line: sorting below is
        # line-based, and <pre> renders &#10; back into the original line breaks.
        body=$(sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/$/\&#10;/' $file | tr -d '\n')

        echo -e "hello the pizza is ready $date<article class=\"rhyme\" id=\"$slug\"><h2 class=\"rhyme__title\"><a href=\"https://github.com/slavaaaaaaaaaa/smaslennikov.github.io/blob/master/rhymes/$file\">$name</a></h2><p class=\"rhyme__meta\">$author &middot; $date</p><pre class=\"rhyme__body\">$body</pre></article>" >> $indextmpfile

        echo "
  <item>
    <title>$name</title>
    <link>https://github.com/slavaaaaaaaaaa/smaslennikov.github.io/blob/master/rhymes/$file</link>
    <description>$name by $author on $date</description>
  </item>" >> $rsstmpfile
    fi
done

cat <<EOF > ../_layouts/rhymes.html
---
layout: default
---

<div class="rhymes__head">
  <h1>Rhymes and haikus</h1>
  <p><a href="https://slava.lol/rhymes/rss.xml">subscribe via rss</a></p>
</div>
EOF

cat <<EOF > rss.xml
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
  <title>Slava Maslennikov - Haikus and Rhymes</title>
  <link>https://slava.lol/rhymes</link>
  <description>I was a poet and I didn't even know I was one</description>
  <copyright>2017-2020 Slava Maslennikov. All rights reserved.</copyright>
EOF

sort -k6 -r $indextmpfile | sed -e 's/^.*<article/<article/g' | sed -e 's/\(....-..-..\)T\([0-9:]*\)/\1 \2/' -e 's/Z$//' >> ../_layouts/rhymes.html

cat $rsstmpfile >> rss.xml

cat <<EOF >> rss.xml
</channel>
</rss>
EOF
