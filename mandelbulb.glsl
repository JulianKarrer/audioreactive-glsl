#ifdef GL_ES
precision mediump float;
#endif

#define PI 3.1415926535

/*{
  "audio": true,  // VEDA.js - enable audio input for this file/*
}*/

    //CONFIG
//raymarching
#define MAX_RAYMARCH_STEPS 1000
#define SURFACE_DIST 0.001
//mandelbulb
#define POWER 4.
#define MANDELBULB_MAX_ITERATIONS 100
#define R 2.
//visual
#define BRIGHTNESS 2.

    //AUDIO
//fft percentage breakpoints between bass, mid and treble frequencies
const vec2 bp = vec2(0.02,0.3);
// 1/x factors for bass, treble and high intensity (colour, -, FOV)
const vec3 reduction = vec3(40.);

#define BPM 130.

uniform vec2 resolution;
uniform float time;
uniform sampler2D backbuffer;

uniform sampler2D spectrum;




        //AUDIO FUNCTIONS
float getTime(){
    return time * 2. * PI * (1./4.) * BPM * (1./60.)  + PI/10.;
}

vec4 getAudioProfile(){
    vec3 res = vec3(1./3.);
    float total = 1.;

    //percentage breakpoints between bass, middle and high
    float samples = 100.;
    for(int i = 0;  i < 100; i++)
    {
        float val = texture2D(spectrum, vec2(float(i)/samples ,0.5)).r;
        //normalize pink to white noise spectrum
        val *= (1.*(float(i)/samples)+0.5);

        total += val;
        if (float(i) < samples*bp.x){
            res.x += val;
        }
        else{
            if (samples*bp.x < float(i) && float(i) < samples*bp.y){
                res.y += val;
            }
            else {
                res.z += val;
            }
        }
    }

    //res /= 2.*max(max(res.x,res.y),res.z);
    //res /= total;
    res /= reduction;

    return vec4(res, total);

}

vec3 debugSpectrum(vec2 uv,vec3 color){
    //white spectogram
    if(abs(texture2D(spectrum, vec2(uv.x*1. ,0.)).r *(1.*uv.x+0.5) - (uv.y)) < 0.003){
        color = vec3(1.);
    }
    //bass, treble, high bar graph
    color.r += float(abs(getAudioProfile().x - uv.y)<0.002) * float(uv.x < bp.x);
    color.g += float(abs(getAudioProfile().y - uv.y)<0.002) * float(bp.x < uv.x && uv.x < bp.y);
    color.b += float(abs(getAudioProfile().z - uv.y)<0.002) * float(bp.y < uv.x && uv.x < 1.);

    return color;
}


        //GEOMETRY FUNCTIONS

float currentPow(){
    return POWER - 3.*cos(getAudioProfile().x*0.2 +(1./8.)*getTime());
}

//distance estimator calculates the distance to the rendered object given a point in space
//returns the distance and number of steps until divergant

vec2 DE(vec3 pos) {
    //resources:/
    //https://en.wikipedia.org/wiki/Mandelbulb
    //http://blog.hvidtfeldts.net/index.php/2011/06/distance-estimated-3d-fractals-part-i
    //https://en.wikipedia.org/wiki/Spherical_coordinate_system#Cartesian_coordinates

    float n = currentPow();
    int iterations = 0;

	vec3 z = pos;
	float r = length(pos);
	float dr = 1.;

	for (int i = 0; i < MANDELBULB_MAX_ITERATIONS ; i++) {
        //first, check if maximum radius was escaped
        r = length(z);
        if (r>R) break;

        //keep track of i to determine escape speed
        iterations = i;

        //convert to polar coordinates
    		float theta = acos(z.z / r);
    		float phi = atan(z.y, z.x);
        //enable additional pow on one of the angles to make things funky
        //phi = n*phi;

        //calculate z = z_0 + z^n
        //using polar coordinates for exponents: z_0 + r^n * (sin(n*theta)cos(n*phi),  sin(n*theta)sin(n*phi),  cos(n*theta))
		    z = pos + pow(r,n) * vec3(sin(n*theta)*cos(n*phi), sin(n*theta)*sin(n*phi), cos(n*theta));

        //accumulate spatial derivative for distance estimation
		    dr = dr * n * pow(r, n - 1.) + 1.;

	}
    float smoothie =  float(iterations) + log(log(R*R))/log(POWER) - log(log(dot(z,z)))/log(POWER);
	return vec2( 0.5*log(r)*r/dr, smoothie );
}


//raymarching to object defined by DE()
vec2 trace(vec3 o, vec3 r){
	float d = 0.;
	int s = 0;
	for (int i = 0; i < MAX_RAYMARCH_STEPS; i ++){
		vec3 p = o + r * d;
		float cur_d = DE(p).x;
        d += cur_d;
		s = i;
		if (cur_d < SURFACE_DIST) break;
	}
	//return the objects estimated distance and number of steps to get there
	return vec2(float(s)/float(MAX_RAYMARCH_STEPS), DE(o+r*d*0.99).y);
}

        //GRAPHICS FUNCTIONS

vec3 hsv2rgb( in vec3 c ){
    //via https://www.shadertoy.com/view/MsS3Wc
    vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );
    return c.z * mix( vec3(1.0), rgb, c.y);
}

vec3 colorize(vec2 res, vec2 bp){
    //brightness
    float b = pow(res.x, 0.12);  //reduce brightness in pow, increase linearly in return -> contrast
    b = 1.-b;
    b *= currentPow()*0.05;
    //colour
    float c = 1.-pow(res.y,1.5)/(float(MAX_RAYMARCH_STEPS)*0.3);
    //float c = res.y;
    c += time*0.1;
    c += getAudioProfile().x * 2.5; + getTime()*0.1;
    c = mod(c, 1.);

    vec3 colour = hsv2rgb(vec3(c,.4, BRIGHTNESS*b*(1.5*getAudioProfile().w + 40.)/90.));
    return mix(vec3(0.), colour, ((2.)+res.y)/3. );
}


        //MAIN FUNCTION

void main( void ) {
    //UV
	//normalize uv to [-1;1] and adjust aspect ratio
    vec2 p = (gl_FragCoord.xy * 2. - resolution) / min(resolution.x, resolution.y);
    vec2 uv = gl_FragCoord.xy / resolution;

    //CAMERA
    //setup origin and FOV
    vec3 o = vec3(0.,0.,-4.);
    float FOV = 2.0 + getAudioProfile().z * 1.2; //higher number = zoomed in
    vec3 cameraDir = normalize(vec3(p, FOV));

    //make the camera rotate
    float t = (1./8.)*getTime();

    o.xz         *= mat2(cos(t), -sin(t), sin(t), cos(t));
    cameraDir.xz *= mat2(cos(t), -sin(t), sin(t), cos(t));

    o.xy         *= mat2(cos(t), -sin(t), sin(t), cos(t));
    cameraDir.xy *= mat2(cos(t), -sin(t), sin(t), cos(t));

    o.yz         *= mat2(cos(t), -sin(t), sin(t), cos(t));
    cameraDir.yz *= mat2(cos(t), -sin(t), sin(t), cos(t));

    //RENDER
    vec3 color = vec3(0.);
    //color += debugSpectrum(uv, color);
    color += colorize(trace(o, cameraDir), bp);

                                        //trailing images - reverb effect
  	gl_FragColor = vec4(color + texture2D(backbuffer, vec2(uv.x,1.-uv.y)).xyz * .7 , 1.);

}
