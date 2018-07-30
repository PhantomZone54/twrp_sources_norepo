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

# Show Total Sizes of the checked-out non-repo files
cd $DIR
echo -en "The total size of the checked-out files is ---  "
du -sh $RecName
cd $RecName

# Get the Version
export version=$(cat bootable/recovery/variables.h | grep "define TW_MAIN_VERSION_STR" | cut -d '"' -f2)
echo -en "The Recovery Version is -- " && echo $version

# Compress non-repo folder in one piece
echo -e "Compressing files --- "
echo -e "Please be patient, this will take time"

export XZ_OPT=-9e
time tar -I pxz -cf $RecName-$BRANCH-norepo-$(date +%Y%m%d).tar.xz *
echo -e "Compression Done"

mkdir -p ~/project/files/ && mv $RecName-$BRANCH-norepo-$(date +%Y%m%d).tar.xz ~/project/files/
cd ~/project/files

# Make a Compressed file list for future reference
tar -tJvf *.tar.xz | awk '{print $6}' >> $RecName-$BRANCH-norepo-$(date +%Y%m%d).filelist.txt
echo -en "Size of filelist text is -- " && du -sh *.filelist.txt
tar -I pxz -cf $RecName-$BRANCH-norepo.fullfilelist.tar.xz *.txt
echo -en "Size of Compressed filelist is -- " && du -sh *.fullfilelist.tar.xz
rm *.filelist.txt

# Take md5
md5sum $RecName-$BRANCH-norepo-*.tar.xz > $RecName-$BRANCH-norepo-$(date +%Y%m%d).md5sum

# Move the filelist for upload too
mv $RecName-$BRANCH-norepo.fullfilelist.tar.xz ~/project/files/ || echo "move filelist error"

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
ghr -u $GitHubName -t $GITHUB_TOKEN -b 'Relesing Latest $RecName Sources'  v$version files

echo -e "\nCongratulations! Job Done!"