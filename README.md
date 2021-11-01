## TWRP Compressed (NoRepo)
### [PROJECT ABANDONED]
[![CircleCI](https://circleci.com/gh/PhantomZone54/twrp_sources_norepo.svg?style=svg)](https://circleci.com/gh/PhantomZone54/twrp_sources_norepo)


### Download
[Latest Release](https://github.com/PhantomZone54/twrp_sources_norepo/releases/latest)


### How To Uncompress

If the filenames has suffix like .aa or .ab, then they are split into multiple sizes (not multi-volume archives).

You need to used a command like this to unpack them correctly -

```bash
cat MinimalOmniRecovery-twrp-9.0-norepo-20210130.tzst.* | tar --zstd -xv
```
