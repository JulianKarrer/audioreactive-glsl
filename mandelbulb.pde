import ddf.minim.analysis.*;
import ddf.minim.*;
import java.io.*;
import java.util.Arrays;

PShader shader;

int FPS = 60;

//Paths
String GLSL_PATH = "mandelbulb.glsl";
String MP3_PATH = "MUD.mp3";
String TIFF_OUT_PATH = "out";


//set to true to convert song to spectrum data, false to view the animation
//  saving creates a .bin file for the mp3 in the data directory. once this file exists, you may set "saving" to false.
boolean saving = false;
//set this to true in addition to saving = false to render the video to disk
boolean rendering = false;


//Audio
int FFT_BANDS = 1024;
float SMOOTHING_CONSTANT = 0.88;

Minim       minim;
AudioPlayer song;
FFT         fft;
float[][] spectrum;
float[][] spectrum_des;
PImage fftTexture = new PImage(FFT_BANDS, 1);


//Visual

PImage backbuffer = new PImage(width, height);
float TPS = 1000./FPS;





void setup() {
    //size(3840, 2160, P3D);      //4K
    //size(1920, 1080, P3D);    //Full HD
    size(720, 480, P3D);      //Preview SD
    
    
    frameRate(FPS);

    //load and compile shader
    shader = loadShader(GLSL_PATH);


    if(saving){
     //create audio context and initialize fft
      minim = new Minim(this);
      song = minim.loadFile(MP3_PATH, FFT_BANDS);
      fft = new FFT( song.bufferSize(), song.sampleRate() );
      spectrum = new float[ceil(song.length()*(FPS/1000.))][FFT_BANDS+1];
      song.play();
      //song.mute();
    }
    
    
    if(!saving){deserialize();}

}


boolean saved = false;
int framecount = 0;
void draw() {
  if (saving){
    if(song.isPlaying() && !saved){saveFftFile();}
    else {
      //serialize spectrum[][] to disk
      saveFftFile();
      saved = true; serialize();}
  }
  else{
      println(framecount);
      
      //search smallest x such that time <= spectrum[x][FFT_BANDS]
      int x = -1;
      float curTime = spectrum[0][FFT_BANDS] + TPS*framecount;
      for (int i=0; i < spectrum.length; i++){
        if (spectrum[i][FFT_BANDS] > curTime){
          x = i;
          break;
        }
      }
      if (x < 0){x = 0; exit();}
      
      //interpolate FFT readings depending on their timestamp and current frame time
      for (int i = 0; i <  FFT_BANDS; i++) {
        float interpolation = (curTime - spectrum[x>0?x-1:1][FFT_BANDS]) / (spectrum[x][FFT_BANDS] - spectrum[x>0?x-1:1][FFT_BANDS]);
        float currentVal = (spectrum[x][i]*(1-interpolation) + spectrum[x>0?x-1:1][i]*interpolation);
        
        //create the fft texture to be pushed into the uniform
        fftTexture.set(i, 0, color(floor(255*min(currentVal, 1))));
      }
      
      //update uniforms
      shader(shader);
      shader.set("resolution", float(width), float(height));
      shader.set("time", TPS*framecount/1000);
      shader.set("spectrum", fftTexture);
      shader.set("backbuffer", backbuffer);
      rect(0, 0, width, height);
  
      //save new image to backbuffer
      backbuffer = get();
      
      //save img to disk if rendering
      if(rendering){save("./"+TIFF_OUT_PATH+"/"+nf(framecount,6)+".tif");};
    
    }
    
    framecount ++;
}


void saveFftFile(){
    //update fft
    fft.forward(song.mix);
    //save fft to spectrum array[][]
    for (int i = 0; i <  FFT_BANDS; i++) {
      spectrum[framecount][i] = (fft.getBand(i)*(1-SMOOTHING_CONSTANT) + spectrum[framecount>0?framecount-1:0][i]*SMOOTHING_CONSTANT);
    }
    //include a timestamp per frame in milliseconds
    //  this is used to interpolate fft values when rendering based on the framecount, 
    //  so that the animation is in sync with the audio even if rendering each frame takes a while.
    spectrum[framecount][FFT_BANDS] = millis();
    
}

void serialize() {
    try {
      //try creating the file if it doesnt exist already
        File file = new File(dataPath(MP3_PATH+".bin"));
        file.createNewFile();
        //serialize to file
        FileOutputStream f = new FileOutputStream(dataPath(MP3_PATH+".bin"));
        ObjectOutputStream o = new ObjectOutputStream(f);
        o.writeObject(spectrum);
        o.close();
        exit();
    }
    catch(Exception e) {print(e);}
}

void deserialize(){
    try {
        FileInputStream f = new FileInputStream(dataPath(MP3_PATH+".bin"));
        ObjectInputStream o = new ObjectInputStream(f);
        spectrum = (float[][]) o.readObject();
        o.close();
    } catch(Exception e){print(e);}
}
