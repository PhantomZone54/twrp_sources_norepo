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
sudo apt-get update -qqy && sudo apt-get upgrade -qqy
sudo apt-get install pxz wput -qqy

echo -e "ReEnable PATH and Set Repo & GHR"
mkdir ~/bin ; echo ~/bin || echo "bin folder creation error"
sudo curl --silent --create-dirs -L -o /usr/local/bin/repo -O -L https://github.com/akhilnarang/repo/raw/master/repo
sudo cp .circleci/ghr ~/bin/ghr
sudo chmod a+x /usr/local/bin/repo
PATH=~/bin:/usr/local/bin:$PATH && echo $PATH

echo -e "Github Authorization"
git config --global user.email $GitHubMail && git config --global user.name $GitHubName
git config --global color.ui true

echo -e "Initial Disc Usage ..."
df -hlT

echo -e "Main Function Starts HERE"
cd $DIR; mkdir $RecName; cd $RecName

echo -e "Initialize the repo data fetching"
repo init -q -u $LINK -b $BRANCH --depth 1 || repo init -q -u $LINK --depth 1

echo -e "Sync it up"
sudo repo sync -c -f -q --force-sync --no-clone-bundle --no-tags -j32
echo -e "\nSHALLOW Source Syncing done\n"

echo -e "Own all the files to circleci user"
sudo chown -R circleci:circleci * .

echo -e "Remove the .repo chunks"
rm -rf .repo/

echo -e "Remove all the .git folders from withing every Repositories"
find . \( -name ".git" -o -name ".gitignore" -o -name ".gitmodules" -o -name ".gitattributes" \) -exec rm -rf -- {} +

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

# Compression quality
export XZ_OPT=-6

if [ $DDF -gt 8192 ]; then
  mkdir $DIR/parts
  echo -e "Compressing and Making 1.75GB parts Because of Huge Data Amount \nBe Patient..."
  time tar -I pxz -cf - * | split -b 1792M - ~/project/files/$RecName-$BRANCH-norepo-$(date +%Y%m%d).tar.xz.
  # Show Total Sizes of the compressed .repo
  echo -en "Final Compressed size of the consolidated checked-out files is ---  "
  du -sh ~/project/files/
else
  time tar -I pxz -cf ~/project/files/$RecName-$BRANCH-norepo-$(date +%Y%m%d).tar.xz *
  echo -en "Final Compressed size of the consolidated checked-out archive is ---  "
  du -sh ~/project/files/$RecName-$BRANCH-norepo*.tar.xz
fi

echo -e "Compression Done"

echo -e "Final Disc Usage After Compression ..."
df -hlT

cd ~/project/files

echo -e "Taking md5 Hash"
md5sum * > $RecName-$BRANCH-norepo-$(date +%Y%m%d).md5sum
cat $RecName-$BRANCH-norepo-$(date +%Y%m%d).md5sum

# Show Total Sizes of the compressed files
echo -en "Final Compressed size of the checked-out files is ---  "
du -sh ~/project/files/

echo -e "Show all major contents of the project root folder"
ls -la ~/project/

# Make a Compressed file list for future reference
cd ~/project/$RecName
ls -AhxcRis . >> $RecName-$BRANCH-*.file.log || echo "filelist generation error"
echo -en "Size of filelist text is -- " && du -sh *.file.log
tar -I pxz -cf ~/project/files/$RecName-$BRANCH-norepo.filelist.tar.xz *.file.log
rm *.file.log

cd $DIR
echo -e "Basic Cleanup"
rm -rf $RecName

echo -e "Preparing for Upload"
cd ~/project/files/
for file in $RecName-$BRANCH*; do wput $file ftp://"$FTPUser":"$FTPPass"@"$FTPHost"//$RecName-NoRepo/ ; done
echo -e " Done uploading to AFH"

cd ~/project/
ghr -u $GitHubName -t $GITHUB_TOKEN -b "Releasing Latest TWRP Sources using OmniROM's Minimal-Manifest" v$version-$(date +%Y%m%d) files/

echo -e "\nCongratulations! Job Done!"

rm -rf files/
