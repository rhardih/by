#/usr/bin/env bash

toolchain_to_arch() {
  case $1 in
    arm-*)
      echo arm
      ;;
    x86-*)
      echo x86
      ;;
    mipsel-*)
      echo mips
      ;;
    aarch64-*)
      echo arm64
      ;;
    x86_64-linux-android-*)
      echo x86_64 | sed -e 's/-linux-android//'
      ;;
    x86_64-*)
      echo x86_64
      ;;
    mips64el-*)
      echo mips64
      ;;
    *)
      echo "Invalid toolchain $1"
      exit 1
      ;;
  esac
}

base="https://dl.google.com/android/repository"
output="ndk_info.yml"
list="ndks.sha"

for file in $(awk '{print $2}' < $list); do
  wget -N "$base/$file"
done

shasum -c $list

echo "# This configuration was autogenerated by gen_info.sh" > $output

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
  toolchains=$(tar -tf $file | grep -E "$folder/toolchains.*bin" | \
    awk -F/ '{print $3}' | uniq | gsort -V)

  declare min0
  declare min1

  check_min=0

  # TODO: Replace these repetitions with a fallthrough when on bash > 4
  case "$ndk_name" in
    *r12b*)
      min0=9
      min1=21
      check_min=1
      ;;
    *r13b*)
      min0=9
      min1=21
      check_min=1
      ;;
    *r14b*)
      min0=9
      min1=21
      check_min=1
      ;;
    *r15c*)
      min0=14
      min1=21
      check_min=1
      ;;
    *r16*)
      min0=14
      min1=21
      check_min=1
      ;;
  esac

  echo "  toolchains:" >> $output
  for t in $toolchains; do
    echo "    - $t" >> $output
  done

  echo "  platforms:" >> $output

  for p in $platforms; do
    echo "    $p:" >> $output
    for t in $toolchains; do
      if [[ check_min != 0 ]]; then
        version=${p#"android-"}
        arch=$(toolchain_to_arch "$t")
        min=$min1

        if [[ "$arch" =~ ^(arm|mips|x86)$ ]]; then
          min=9
        fi

        if (( $version >= $min )); then
          echo "      - $t" >> $output
        fi
      else
        echo "      - $t" >> $output
      fi
    done
  done
done < $list
