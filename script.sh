#!/bin/bash

# Authors - Neil "regalstreak" Agarwal, Harsh "MSF Jarvis" Shandilya, Tarang "DigiGoon" Kagathara
# 2017
# -----------------------------------------------------
# Modified by - Rokib Hasan Sagar @rokibhasansagar
# To be used to Release on AndroidFileHost and GitHub
# -----------------------------------------------------

# Definitions
DIR=$(pwd)
echo -en "Current directory is -- " && echo $DIR
RecName=$1
LINK=$2
BRANCH=$3
GitHubMail=$4
GitHubName=$5
FTPHost=$6
FTPUser=$7
FTPPass=$8

echo -e "Making Update and Installing Apps"
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install pxz wput -y

echo -e "ReEnable PATH and Set Repo & GHR"
mkdir ~/bin ; echo ~/bin || echo "bin folder creation error"
sudo curl --create-dirs -L -o /usr/local/bin/repo -O -L https://github.com/akhilnarang/repo/raw/master/repo
sudo cp .circleci/ghr ~/bin/ghr
sudo chmod a+x /usr/local/bin/repo
PATH=~/bin:/usr/local/bin:$PATH && echo $PATH

echo -e "Github Authorization"
git config --global user.email $GitHubMail && git config --global user.name $GitHubName
git config --global color.ui true

echo -e "Main Function Starts HERE"
cd $DIR; mkdir $RecName; cd $RecName

echo -e "Initialize the repo data fetching"
repo init -q -u $LINK -b $BRANCH --depth 1 || repo init -q -u $LINK --depth 1

echo -e "Sync it up"
time repo sync -c -f -q --force-sync --no-clone-bundle --no-tags -j32
echo -e "\nSHALLOW Source Syncing done\n"

rm -rf .repo/

# Show and Record Total Sizes of the checked-out non-repo files
cd $DIR
echo -en "The total size of the checked-out files is ---  "
du -sh $RecName
DDF=$(du -sh -BM $RecName | awk '{print $1}' | sed 's/M//')
echo -en "Value of DDF is  --- " && echo $DDF

# Get the Version
export version=$(cat bootable/recovery/variables.h | grep "define TW_MAIN_VERSION_STR" | cut -d '"' -f2)
echo -en "The Recovery Version is -- " && echo $version

cd $RecName

# Compress non-repo folder in one piece
echo -e "Compressing files --- "
echo -e "Please be patient, this will take time"

mkdir -p ~/project/files/

export XZ_OPT=-9e

if [ $DDF -gt 8192 ]; then
  mkdir $DIR/parts
  echo -e "Compressing and Making 2GB parts Because of Huge Data Amount \nBe Patient..."
  time tar -I pxz -cf - * | split -b 2048M - ~/project/files/$RecName-$BRANCH-norepo-$(date +%Y%m%d).tar.xz.
  # Show Total Sizes of the compressed .repo
  echo -en "Final Compressed size of the consolidated checked-out files is ---  "
  du -sh ~/project/files/
else
  time tar -I pxz -cf ~/project/files/$RecName-$BRANCH-norepo-$(date +%Y%m%d).tar.xz *
  echo -en "Final Compressed size of the consolidated checked-out archive is ---  "
  du -sh ~/project/files/$RecName-$BRANCH-norepo*.tar.xz
fi

echo -e "Compression Done"

cd ~/project/files

# Make a Compressed file list for future reference
tar -tJvf *.tar.xz.* | awk '{print $6}' >> $RecName-$BRANCH-norepo-$(date +%Y%m%d).file.log
echo -en "Size of filelist text is -- " && du -sh *.file.log
tar -I pxz -cf $RecName-$BRANCH-norepo.filelist.tar.xz *.file.log
echo -en "Size of Compressed filelist is -- " && du -sh *.filelist.tar.xz
rm *.file.log

# Take md5
md5sum $RecName-$BRANCH-norepo-*.tar.xz.* > $RecName-$BRANCH-norepo-$(date +%Y%m%d).md5sum

# Show Total Sizes of the compressed files
echo -en "Final Compressed size of the checked-out files is ---  "
du -sh ~/project/files/

cd $DIR
# Basic Cleanup
rm -rf $RecName

cd ~/project/files/
for file in $RecName-$BRANCH*; do wput $file ftp://"$FTPUser":"$FTPPass"@"$FTPHost"//$RecName-NoRepo/ ; done
echo -e " Done uploading to AFH"

cd ~/project/
ghr -u $GitHubName -t $GITHUB_TOKEN -b "Releasing Latest TWRP Sources using OmniROM's Minimal-Manifest" v$version-$(date +%Y%m%d) files

echo -e "\nCongratulations! Job Done!"
