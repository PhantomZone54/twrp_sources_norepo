#!/bin/bash

# Authors - Neil "regalstreak" Agarwal, Harsh "MSF Jarvis" Shandilya, Tarang "DigiGoon" Kagathara
# 2017
# -----------------------------------------------------
# Modified by - Rokib Hasan Sagar @rokibhasansagar
# To be used to Release on AndroidFileHost and GitHub
# -----------------------------------------------------

# Definitions
DIR=$(pwd)
RecName=$1
LINK=$2
BRANCH=$3

# Some Machine Info
lscpu
df -hlT

echo -e "Github Authorization"
git config --global user.email $GitHubMail
git config --global user.name $GitHubName
git config --global color.ui true

git clone -q "https://$GITHUB_TOKEN@github.com/rokibhasansagar/google-git-cookies.git" &> /dev/null
if [ -e google-git-cookies ]; then
  bash google-git-cookies/setup_cookies.sh
  rm -rf google-git-cookies
fi

echo -e "Main Function Starts HERE"
cd $DIR; mkdir $RecName; cd $RecName

echo -e "Initialize the repo data fetching"
repo init -q -u $LINK -b $BRANCH --depth 1 || repo init -q -u $LINK --depth 1

echo -e "Removing Unimportant Darwin-specific Files from syncing"
cd .repo/manifests
sed -i '/darwin/d' default.xml
( find . -type f -name '*.xml' | xargs sed -i '/darwin/d' ) || true
git commit -a -m "Magic" || true
cd ../
sed -i '/darwin/d' manifest.xml
cd ../

echo -e "Sync it up"
repo sync -c -q --force-sync --no-clone-bundle --optimized-fetch --prune --no-tags -j$(nproc --all)
echo -e "\nSHALLOW Source Syncing done\n"

echo -e "Remove all the .git folders from withing every Repositories"
find . \( -name ".git" -o -name ".gitignore" -o -name ".gitmodules" -o -name ".gitattributes" \) -exec rm -rf -- {} +

echo -e "Remove the .repo chunks"
rm -rf .repo/

echo -e "Show and Record Total Sizes of the checked-out non-repo files"
cd $DIR
echo -en "The total size of the checked-out files is ---  "
du -sh $RecName
DDF=$(du -sh -BM $RecName | awk '{print $1}' | sed 's/M//')
echo -en "Value of DDF is  --- " && echo $DDF

echo -e "Disc Usage After Repo Sync and Clear Stuffs ..."
df -hlT

cd $RecName

# Get the Version
export version=$(cat bootable/recovery/variables.h | grep "define TW_MAIN_VERSION_STR" | cut -d '"' -f2)
echo -en "The Recovery Version is -- " && echo $version

# Compress non-repo folder in one piece
echo -e "Compressing files --- "
echo -e "Please be patient, this will take time"
# Take a break
sleep 3s

mkdir -p ~/project/files/
datetime=$(date +%Y%m%d)

# Compression quality
export XZ_OPT="-9"

if [ $DDF -gt 6912 ]; then
  mkdir $DIR/parts
  echo -e "Compressing and Making 1.2GB parts Because of Huge Data Amount \nBe Patient..."
  tar -cJf - * | split -b 1228M - ~/project/files/$RecName-$BRANCH-norepo-$datetime.tar.xz.
  # Show Total Sizes of the compressed .repo
  echo -en "Final Compressed size of the consolidated checked-out files is ---  "
  du -sh ~/project/files/
else
  tar -cJf ~/project/files/$RecName-$BRANCH-norepo-$datetime.tar.xz *
  echo -en "Final Compressed size of the consolidated checked-out archive is ---  "
  du -sh ~/project/files/$RecName-$BRANCH-norepo*.tar.xz
fi

echo -e "Compression Done"

echo -e "Final Disc Usage After Compression ..."
df -hlT

cd ~/project/files

echo -e "Taking md5 Hash"
md5sum * > $RecName-$BRANCH-norepo-$datetime.md5sum
cat $RecName-$BRANCH-norepo-$datetime.md5sum

# Show Total Sizes of the compressed files
echo -en "Final Compressed size of the checked-out files is ---  "
du -sh ~/project/files/*

# Make a Compressed file list for future reference
cd ~/project/$RecName
ls -AhxcRis . >> $RecName-$BRANCH-*.file.log || echo "filelist generation error"
echo -en "Size of filelist text is -- " && du -sh *.file.log
tar -cJf ~/project/files/$RecName-$BRANCH-norepo.filelist.tar.xz *.file.log
rm *.file.log

cd $DIR
echo -e "Basic Cleanup"
rm -rf $RecName

echo -e "Preparing for Upload"
cd ~/project/files/
for file in $RecName-$BRANCH*; do
  echo -e "\nUploading $file ...\n"
  wput $file ftp://"$FTPUser":"$FTPPass"@"$FTPHost"//$RecName-NoRepo/
  sleep 2s
done
echo -e " Done uploading to AFH"

cd ~/project/
rm -f files/core* || true
ghr -u $GitHubName -t $GITHUB_TOKEN -b "Releasing Latest TWRP Sources using OmniROM's Minimal-Manifest" v$version-$datetime files/

echo -e "\nCongratulations! Job Done!"

rm -rf files/
