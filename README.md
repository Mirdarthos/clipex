This script is the result of inspiration found in this Stack Overflow answer:

https://stackoverflow.com/questions/18444194/cutting-multimedia-files-based-on-start-and-end-time-using-ffmpeg/52916510#52916510

This method beccause it was the only one vouched for by the answerer, giving me quite a bit of confidence in it. So I wanted to convert it to a script so that I'm able to use it easily. This quickly morphed into this script, which is a bit diffrent from what I set out to do, but I think it's beautiful nonetheless.

It allows, or helps the user to extract one or more video clips from a larger video using, well I think it's obvious, but it uses `ffmpeg`, without having to buld long and complicated `ffmpeg` commands...wich can be quite hard, especially if you're _new to it_ like me. It also allows you to force keyframes (I presume this means insert keyframes) into the video at the locations specified with `--clip`.

Installation and usage:

Make sure `ffmpeg` and `bc` is installed, then download `clipex.sh` anywhere. It can then be run with:

```
bash /path/to/clipex.sh [-q] [-s] --clip 00:05:38-00:07:47 --clip 00:07:49-00:09:29 --clip 00:09:41-00:13:55 --clip 00:14:12-00:16:39 --clip 00:16:41-00:19:30 --clip 00:20:28-00:25:55 --clip 01:12:34-01:16:56 --input ~/Video/YouTube/originalInputVideoFile.mkv --outputdirectory ~/Video/YouTube/directoryToContainClips
```

**Or** if you prefer you can download it to `$HOME/.local/bin`, or in fact any directory that's in your `$PATH`, enter the directory:

```
cd $HOME/.local/bin
```

Set the newly downloaded script as executable:

```
chmod u=+xrw clipex.sh
```

and run/use it from anywhere:

```
clipex.sh [-q] [-s] --clip 00:05:38-00:07:47 --clip 00:07:49-00:09:29 --clip 00:09:41-00:13:55 --clip 00:14:12-00:16:39 --clip 00:16:41-00:19:30 --clip 00:20:28-00:25:55 --clip 01:12:34-01:16:56 --input ~/Video/YouTube/oRiginalInputVideoFile.mkv --outputdirectory ~/Video/YouTube/directoryToContainClips
```