# audioreactive-glsl

Save audioreactive (VEDA) shaders to video.

The Processing 3 sketch provides built-in uniforms of VEDA such as an FFT spectrum, a backbuffer, time and resolution to easily port existing fragment shaders from VEDA for Atom to Processing.

Audio files specified in the script will be FFT-analysed per-frame and saved to .bin files so that videos of the audioreactive shader can be rendered in non-realtime. This enables 4K 60fps recordings that would be impossible in realtime, while staying in sync to the music.

## Usage

Open the .pde sketch in Processing 3 and configure the top section of the script to suit your needs, specifying paths to your audio file and .glsl shader.
- First, run the script with "saving" set to true to generate the .bin audio file.
- Then, run it again with "saving" false to preview the results.
- Increase the resolution in size() and set "rendering" to true when you are ready to save the image sequence.

*ATTENTION!*
Make sure you have enough drive space, as 1 minute worth of uncompressed 4K60fps image sequences might take up more than 100GB of data.

When the image sequence has been saved, you can use video software of your choice to render a .mp4, personally I use:
```
ffmpeg -r 60 -i out/%06d.tif -i "song.mp3" -c:v libx264 -profile:v high -bf 2 -pix_fmt yuv420p -g 30 -c:a aac -profile:a aac_low -b:a 384k -r 60 -y result.mp4
```

## Example

Example .bin files and a fancy mandelbulb shader are included, you can watch the result by clicking here:

[![watch the video here](https://i.vimeocdn.com/video/1038968759.jpg)](https://vimeo.com/502148586)
