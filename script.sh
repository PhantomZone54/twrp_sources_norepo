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
time repo sync -c -q --force-sync --no-clone-bundle --optimized-fetch --prune --no-tags -j$(nproc --all)
echo -e "\nSHALLOW Source Syncing done\n"

echo -e "\nThe total size of the .repo folder is --- " && du -sh .repo

# Keep the whole .repo/manifests folder
mkdir -p repomanifests && cp -a .repo/manifests repomanifests/
echo "Cleaning up the .repo, no use of it now"
rm -rf .repo
mkdir -p .repo && mv repomanifests/manifests .repo/ && ln -s .repo/manifests/default.xml .repo/manifest.xml && rm -rf repomanifests

#echo -e "Remove all the .git folders from withing every Repositories"
#find . \( -name ".git" -o -name ".gitignore" -o -name ".gitmodules" -o -name ".gitattributes" \) -exec rm -rf -- {} +

cd $DIR
DDF=$(du -sh -BM $RecName | awk '{print $1}' | sed 's/M//')
echo -en "The total size of the checked-out files is --- " && echo "$DDF MB"

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

if [ $DDF -gt 6912 ]; then
  mkdir $DIR/parts
  echo -e "Compressing and Making 1.2GB parts Because of Huge Data Amount \nBe Patient..."
  tar -I'zstd -19 -T2 --long --adapt --format=zstd' -cf - * | split -b 1228M - ~/project/files/$RecName-$BRANCH-norepo-$datetime.tzst. || exit 1
else
  tar -I'zstd -19 -T2 --long --adapt --format=zstd' -cf ~/project/files/$RecName-$BRANCH-norepo-$datetime.tzst * || exit 1
fi

echo -e "Compression Done"

cd ~/project/files

echo -e "Taking md5 Hash"
md5sum * > $RecName-$BRANCH-norepo-$datetime.tzst.md5sum
cat $RecName-$BRANCH-norepo-$datetime.tzst.md5sum

# Show Total Sizes of the compressed files
echo -en "Final Compressed size of the compressed archive ---  "
du -sh ~/project/files/*

# Make a Compressed file list for future reference
cd ~/project/$RecName
ls -AhxcRis . >> $RecName-$BRANCH-*.file.log || echo "filelist generation error"
echo -en "Size of filelist text is -- " && du -sh *.file.log
tar -I'zstd -19 -T2 --long --adapt --format=zstd' -cf ~/project/files/$RecName-$BRANCH-norepo.filelist.tzst *.file.log
rm *.file.log

cd $DIR
echo -e "Basic Cleanup"
rm -rf $RecName

echo -e "Preparing for Upload"
cd ~/project/files/
for file in $RecName-$BRANCH*; do
  echo -e "\nUploading $file to AFH ...\n"
  curl -sS --progress-bar --ftp-create-dirs --ftp-pasv -T $file ftp://"$FTPUser":"$FTPPass"@"$FTPHost"//$RecName-NoRepo/v$version/
  sleep 1s
done
echo -e " Done uploading to AFH"

cd ~/project/
echo -e "\nUploading $file to SF...\n"
{
  echo "exit" | sshpass -p "$SFPass" ssh -tto StrictHostKeyChecking=no $SFUser@shell.sourceforge.net create
} 2>/dev/null
rsync -arvPz --rsh="sshpass -p $SFPass ssh -l $SFUser" files/ $SFUser@shell.sourceforge.net:/home/frs/project/transkadoosh/$RecName-NoRepo/v$version/
echo -e " Done uploading to SF"

rm -f files/core* || true
ghr -t ${GITHUB_TOKEN} -u ${CIRCLE_PROJECT_USERNAME} -r ${CIRCLE_PROJECT_REPONAME} -c ${CIRCLE_SHA1} \
  -b "Releasing Latest TWRP Sources using OmniROM's Minimal-Manifest" v$version-$datetime files/

echo -e "\nCongratulations! Job Done!"

rm -rf files/
