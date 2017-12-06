#/usr/bin/env bash

base="https://dl.google.com/android/repository"
output="ndk_info.yml"
list="ndks.sha"

for file in $(awk '{print $2}' < $list); do
  wget -N "$base/$file"
done

shasum -c $list

echo -n "" > $output

while read line; do
  sha=$(awk '{print $1}' <<< $line)
  file=$(awk '{print $2}' <<< $line)
  folder=${file%-linux-x86_64.zip}
  ndk_name=${folder#android-ndk-}

  echo "$ndk_name:" >> $output

  echo "  url: $base/$file" >> $output
  echo "  sha: $sha" >> $output

  platforms=$(tar -tf $file | grep "$folder/platforms/android-" | \
    awk -F/ '{print $3}' | uniq | gsort -V)

  echo "  platforms:" >> $output
  echo "$platforms" | awk '{print "    - " $1}' >> $output

  toolchains=$(tar -tf $file | grep -E "$folder/toolchains.*bin" | \
    awk -F/ '{print $3}' | uniq | gsort -V)
  echo "  toolchains:" >> $output
  echo "$toolchains" | awk '{print "    - " $1}' >> $output
done < $list