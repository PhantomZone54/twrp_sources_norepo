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

printf "Github Authorization...\n"
git config --global user.email $GitHubMail
git config --global user.name $GitHubName
git config --global color.ui true

git clone -q "https://$GITHUB_TOKEN@github.com/rokibhasansagar/google-git-cookies.git" &> /dev/null
if [ -e google-git-cookies ]; then
  bash google-git-cookies/setup_cookies.sh
  rm -rf google-git-cookies
fi

printf "Main Function Starts HERE\n"
cd $DIR; mkdir $RecName; cd $RecName

printf "Initialize the repo data fetching\n"
repo init -q -u $LINK -b $BRANCH --depth 1 || repo init -q -u $LINK --depth 1

printf "Removing Unimportant Darwin-specific Files from syncing\n"
cd .repo/manifests
sed -i '/darwin/d' default.xml
( find . -type f -name '*.xml' | xargs sed -i '/darwin/d' ) || true
git commit -a -m "Magic" || true
cd ../
sed -i '/darwin/d' manifest.xml
cd ../

printf "Syncing it up...\n"
time repo sync -c -q --force-sync --no-clone-bundle --optimized-fetch --prune --no-tags -j$(nproc --all)
printf "SHALLOW Source Syncing done\n"

printf "\nThe total size of the .repo folder was --- " && du -sh .repo

# Keep the whole .repo/manifests folder
mkdir -p repomanifests && cp -a .repo/manifests repomanifests/
printf "Cleaning up the .repo, no use of it now\n"
rm -rf .repo
mkdir -p .repo && mv repomanifests/manifests .repo/ && ln -s .repo/manifests/default.xml .repo/manifest.xml && rm -rf repomanifests

# Use the patched roomservice file to fix broken lunch munu
md5sum build/tools/roomservice.py 2>/dev/null || md5sum vendor/omni/build/tools/roomservice.py 2>/dev/null
find build/tools -maxdepth 2 -type f -name "roomservice.py" -exec rm -rf {} \; 2>/dev/null
find vendor/omni/build/tools -maxdepth 2 -type f -name "roomservice.py" -exec rm -rf {} \; 2>/dev/null
if [[ $BRANCH =~ twrp-5.1 ]]; then
  curl -sL https://gist.github.com/rokibhasansagar/247ddd4ef00dcc9d3340397322051e6a/raw/roomservice_51.py -o build/tools/roomservice.py
elif [[ $BRANCH =~ twrp-6.0 ]]; then
  curl -sL https://gist.github.com/rokibhasansagar/247ddd4ef00dcc9d3340397322051e6a/raw/roomservice_60.py -o build/tools/roomservice.py
elif [[ $BRANCH =~ twrp-7.1 ]]; then
  curl -sL https://gist.github.com/rokibhasansagar/247ddd4ef00dcc9d3340397322051e6a/raw/roomservice_71.py -o build/tools/roomservice.py
elif [[ $BRANCH =~ twrp-8.1 ]]; then
  curl -sL https://gist.github.com/rokibhasansagar/247ddd4ef00dcc9d3340397322051e6a/raw/roomservice_81.py -o vendor/omni/build/tools/roomservice.py
elif [[ $BRANCH =~ twrp-9.0 ]]; then
  curl -sL https://gist.github.com/rokibhasansagar/247ddd4ef00dcc9d3340397322051e6a/raw/roomservice_90.py -o vendor/omni/build/tools/roomservice.py
fi
chmod 755 build/tools/roomservice.py vendor/omni/build/tools/roomservice.py 2>/dev/null
md5sum build/tools/roomservice.py 2>/dev/null || md5sum vendor/omni/build/tools/roomservice.py 2>/dev/null

cd $DIR
DDF=$(du -sh -BM $RecName | awk '{print $1}' | sed 's/M//')
printf "The total size of the checked-out files is --- " && printf "%s MB\n" "$DDF"

cd $RecName

# Get the Version
export version=$(cat bootable/recovery/variables.h | grep "define TW_MAIN_VERSION_STR" | cut -d '"' -f2)
printf "The Recovery Version is -- " && printf "$s\n" $version

# Compress non-repo folder in one piece
printf "Compressing files --- \n"
printf "Please be patient, this will take time\n"
# Take a break
sleep 2s

mkdir -p ~/project/files/
datetime=$(date +%Y%m%d)

if [ $DDF -gt 6144 ]; then
  printf "Compressing and Making 1 GB parts Because of Huge Data Amount \nBe Patient...\n"
  tar -I'zstd -19 -T3 --long --adapt --format=zstd' -cf - * | split -b 1024M - ~/project/files/$RecName-$BRANCH-norepo-$datetime.tzst. || exit 1
else
  tar -I'zstd -19 -T3 --long --adapt --format=zstd' -cf ~/project/files/$RecName-$BRANCH-norepo-$datetime.tzst * || exit 1
fi

printf "Compression Done\n"

cd ~/project/files

printf "Taking md5 Hash\n"
md5sum * > $RecName-$BRANCH-norepo-$datetime.tzst.md5sum
cat $RecName-$BRANCH-norepo-$datetime.tzst.md5sum

printf "Final Compressed archives --- \n"
ls -lA ~/project/files/
printf "\n\n"

# Make a Compressed file list for future reference
cd ~/project/$RecName
find . -type f | cut -d'/' -f'2-' > $RecName-$BRANCH-$datetime-filelist.txt || printf "filelist generation error\n"
tar -I'zstd -19 -T2 --long --adapt --format=zstd' -cf ~/project/files/$RecName-$BRANCH-norepo-$datetime.filelist.tzst *filelist.txt
rm *filelist.txt

cd $DIR
printf "Basic Cleanup\n"
rm -rf $RecName

printf "Preparing for Upload...\n"
cd ~/project/files/
for file in $RecName-$BRANCH*; do
  printf "Uploading %s...\n" $file
  curl --progress-bar --ftp-create-dirs --ftp-pasv -T $file ftp://"$FTPUser":"$FTPPass"@"$FTPHost"//$RecName-NoRepo/TWRP-v$version/
  sleep 1s
done
printf "Done uploading to AndroidFileHost\n"

cd ~/project/
printf "Uploading %s to SourceForge...\n" $RecName-$BRANCH
{
  printf "exit\n" | sshpass -p "$SFPass" ssh -tto StrictHostKeyChecking=no $SFUser@shell.sourceforge.net create
  sleep 2s
  printf "exit\n" | sshpass -p "$SFPass" ssh -tto StrictHostKeyChecking=no $SFUser@shell.sourceforge.net create
} 2>/dev/null && printf "Process ended with %d\n" $?
sleep 3s
rsync -arvPz --rsync-path="mkdir -p /home/frs/project/transkadoosh/$RecName-NoRepo/TWRP-v$version/ && rsync" \
  --rsh="sshpass -p $SFPass ssh -v -l $SFUser" files/ $SFUser@shell.sourceforge.net:/home/frs/project/transkadoosh/$RecName-NoRepo/TWRP-v$version/
printf "Done uploading to SourceForge\n"

rm -f files/core* || true
ghr -t ${GITHUB_TOKEN} -u ${CIRCLE_PROJECT_USERNAME} -r ${CIRCLE_PROJECT_REPONAME} -c ${CIRCLE_SHA1} \
  -b "Releasing Latest TWRP Sources using OmniROM's Minimal-Manifest" v$version-$datetime files/

printf "\nCongratulations! Job Done!\n"

rm -rf files/
