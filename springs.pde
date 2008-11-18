import ddf.minim.*;
import ddf.minim.signals.*;
import processing.opengl.*;

final int SPRINGS = 10;
final int POINTS = 100;
double[][] pos = new double[SPRINGS][POINTS];
double[][] vel = new double[SPRINGS][POINTS];
boolean[][] fixed = new boolean[SPRINGS][POINTS];
color[] col = new color[SPRINGS];

Minim minim;
AudioInput mic;
AudioOutput speaker;
SpringSound[] sounds = new SpringSound[SPRINGS];

// k1: spring constant between points on the same string
// k2: spring constant between points on adjacent strings
double k1 = 0.005, k2 = 0.005;
double damping = 0.03;

int spacing = 4;
float angle = 0;

void physics() {
  for(int spring = 0; spring < SPRINGS; spring++) {
    for(int point = 0; point < POINTS; point++) {
      // don't physics the fixed points
      if(fixed[spring][point]) continue;
      
      // kill switch!
      if(mousePressed) {
        pos[spring][point] *= map(mouseY, 0, height, 0.5, 1);
        vel[spring][point] *= map(mouseY, 0, height, 0.5, 1);
        continue;
      }

      double force = 0;

      // horizontal
      if(point > 0)
        force += k1 * (pos[spring][point-1] - pos[spring][point]);
      if(point < POINTS-1)
        force += k1 * (pos[spring][point+1] - pos[spring][point]);

      // vertical
      if(spring > 0)
        force += k2 * (pos[spring-1][point] - pos[spring][point]);
      if(spring < SPRINGS-1)
        force += k2 * (pos[spring+1][point] - pos[spring][point]);

      force -= damping * vel[spring][point]; // damping
      
      // Euler integration (lame, but sometimes passable)
      vel[spring][point] += force;
      pos[spring][point] += vel[spring][point];
    }
  }
}

void painting() {
  background(70);

  pushMatrix();
  rotateY(angle);
  angle += 0.01;
  
  for(int spring = 0; spring < SPRINGS; spring++) {
    
    float radius = 10; // + (SPRINGS-spring)*4;

    pushMatrix();
    translate(0, (SPRINGS-spring) * spacing);
    
    pushMatrix();
    rotateX(PI/2);
    noFill();
    stroke(255, 0, 0);
    ellipse(0, 0, radius*2, radius*2);
    popMatrix();
    
    for(int point = 0; point < POINTS; point++) {

      int c = (int)((pos[spring][point] * 128. + 128.));
      fill(c, c, c);
      noStroke();
      
      /* tower */
      pushMatrix();
      rotateY(map(point, 0, POINTS, 0, 2*PI));
      translate(0, 0, radius + (float) (pos[spring][point]));
      scale(0.3, 1, 1);
      box(4);
      popMatrix();
      /* */
      
      /* pyramid tower *
      pushMatrix();
      translate(0, -(float) (pos[spring][point]));
      rotateY(map(point, 0, POINTS, 0, 2*PI));
      translate(0, 0, radius);
      scale(0.3, 1, 1);
      box(4);
      popMatrix();
      /* */
      
      /* half-sphere *
      pushMatrix();
      rotateX(map(spring, 0, SPRINGS, 0, PI));
      rotateY(map(point, 0, POINTS, 0, PI));
      translate(0, 0, 30 + (float) (pos[spring][point]));
      box(2);
      popMatrix();
      /* */

    }

    popMatrix();

  }
  
  popMatrix();
}

void setup() {
  size(500, 400, OPENGL);
  println(width + ", " + height);
  noStroke();
  
  camera(0.0, -SPRINGS*spacing/10, 50.0, // eyeX, eyeY, eyeZ
         0.0, SPRINGS*spacing/2, 0.0, // centerX, centerY, centerZ
         0.0, 1.0, 0.0); // upX, upY, upZ

  // pick some nice colors
  for(int spring = 0; spring < SPRINGS; spring++)
    col[spring] = color(random(128)+128, random(128)+128, random(128)+128);

  // fix (freeze) the endpoints
  for(int spring = 0; spring < SPRINGS; spring++) {
    fixed[spring][0] = true;
    fixed[spring][POINTS-1] = true;
  }

  // initialize audio
  minim = new Minim(this);
  speaker = minim.getLineOut(Minim.STEREO, 512);
  mic = minim.getLineIn(Minim.MONO, 512);
  for(int spring = 0; spring < SPRINGS; spring++) {
    sounds[spring] = new SpringSound(pos[spring], fixed[spring],
      map(spring, 0, SPRINGS, 0.9, 0.01), Math.pow(2, spring) * 0.1,
      speaker.sampleRate()/mic.sampleRate());
    speaker.addSignal(sounds[spring]);
    mic.addListener(sounds[spring]);
  }
}

void stop() {
  if(mic != null) mic.close();
  if(speaker != null) speaker.close();
  if(minim != null) minim.stop();
  super.stop();
}

void draw() {
  damping = map(mouseY, 0, height, 0, 0.05);
  physics();
  painting();
}

void keyPressed() {
  String letters = "asdfghjkl;";
  String numbers = "1234567890";
  if(numbers.indexOf(key) > -1) {
      for(int spring = 0; spring == 0; spring++)
        for(int point = 1; point < POINTS-1; point++)
          pos[spring][point] += 10*Math.sin(map(point, 0, POINTS, 0, (float) Math.PI*2 * numbers.indexOf(key)));
  } else if(letters.indexOf(key) > -1) {
    for(int spring = 0; spring == 0; spring++)
      pos[spring][(int) map(letters.indexOf(key), 0, letters.length(), 1, POINTS-1)] += 15;
  } else if(key == 'm') {
    for(int spring = 0; spring == 0; spring++)
      sounds[spring].usemic = !sounds[spring].usemic;
  }
}

//It's a different dirivitive though. so you'll have F= -kx and you'll break that into x'' = -kx/m and then you'll solve for v_n+1 using that equation for acceleration evaluated in the future, and then find x_n+1 using v_n+1.

class SpringSound implements AudioSignal, AudioListener
{
  private double[] points;
  private boolean[] fixed;
  private double point;
  private double rate;
  private double gain;
  private double sampleRatio; // # speaker samples per mic sample
  private float last;
  public boolean usemic = false;

  public SpringSound(double[] points, boolean[] fixed, double gain,
      double rate, double sampleRatio) {
    this.points = points;
    this.fixed = fixed;
    this.gain = gain;
    this.rate = rate;
    this.sampleRatio = sampleRatio;
    point = 0;
    last = 0;
  }
  
  synchronized void generate(float[] mono) {
    generate(mono, mono);
  }
 
  synchronized void generate(float[] left, float[] right) {
    for ( int i = 0; i < left.length; i += 1 ) {
      float samp = (float) (points[(int) point] / 100.0 * gain);
      samp = last + 0.2 * (samp - last);
      last = samp;
      left[i] = right[i] = samp;
      point = (point + rate) % points.length;
    }
  }
  
  synchronized void samples(float[] samp) {
    if(!usemic) return;
    
    samples(samp, samp);
  }
  
  synchronized void samples(float[] left, float[] right) {
    if(!usemic) return;

    double p = point;
    int max = (int) (points.length / rate);
    for(int i = left.length-1; i >= 0; i--) {
      if(!fixed[(int) p])
        points[(int) p] += left[0];
      p = (p - rate) % points.length;
      if(p < 0) p = points.length + p;
      
      max--;
      if(max <= 0) break;
    }
  }

  public double pos() { return point; }
}
