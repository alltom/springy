import traer.physics.*;

import ddf.minim.*;
import ddf.minim.signals.*;
import processing.opengl.*;

final int STRINGS = 10;
final int POINTS = 100;
double[][] pos = new double[STRINGS][POINTS];
double[][] vel = new double[STRINGS][POINTS];
boolean[][] fixed = new boolean[STRINGS][POINTS];

Minim minim;
AudioInput mic;
AudioOutput speaker;
SpringSound[] sounds = new SpringSound[STRINGS];

// k1: spring constant between points on the same string
// k2: spring constant between points on adjacent strings
double k1 = 0.005, k2 = 0.05;
double damping = 0.03;

int spacing = 4;
float angle = 0;

void physics() {
  for(int string = 0; string < STRINGS; string++) {
    for(int point = 0; point < POINTS; point++) {
      // don't physics the fixed points
      if(fixed[string][point]) continue;

      double force = 0;

      // horizontal
      if(point > 0)
        force += k1 * (pos[string][point-1] - pos[string][point]);
      if(point < POINTS-1)
        force += k1 * (pos[string][point+1] - pos[string][point]);

      // vertical
      if(string > 0)
        force += k2 * (pos[string-1][point] - pos[string][point]);
      if(string < STRINGS-1)
        force += k2 * (pos[string+1][point] - pos[string][point]);

      force -= damping * vel[string][point]; // damping

      // Euler integration (lame, but sometimes passable)
      vel[string][point] += force;
      pos[string][point] += vel[string][point];

      // kill switch!
      if(mousePressed) {
        pos[string][point] *= map(mouseY, 0, height, 0.5, 1);
        vel[string][point] *= map(mouseY, 0, height, 0.5, 1);
      }
    }
  }
}

void painting() {
  background(70);

  pushMatrix();
  rotateY(angle);
  angle += 0.01;

  for(int string = 0; string < STRINGS; string++) {

    float radius = 10; // + (STRINGS-string)*4;

    pushMatrix();
    translate(0, (STRINGS-string) * spacing);

    pushMatrix();
    rotateX(PI/2);
    noFill();
    stroke(255, 0, 0);
    ellipse(0, 0, radius*2, radius*2);
    popMatrix();

    for(int point = 0; point < POINTS; point++) {

      int c = (int)((pos[string][point] * 128. + 128.));
      fill(c, c, c);
      noStroke();

      /* tower */
      pushMatrix();
      rotateY(map(point, 0, POINTS, 0, 2*PI));
      translate(0, 0, radius + (float) (pos[string][point]));
      scale(0.3, 1, 1);
      box(4);
      popMatrix();
      /* */

      /* pyramid tower *
      pushMatrix();
      translate(0, -(float) (pos[string][point]));
      rotateY(map(point, 0, POINTS, 0, 2*PI));
      translate(0, 0, radius);
      scale(0.3, 1, 1);
      box(4);
      popMatrix();
      /* */

      /* half-sphere *
      pushMatrix();
      rotateX(map(string, 0, STRINGS, 0, PI));
      rotateY(map(point, 0, POINTS, 0, PI));
      translate(0, 0, 30 + (float) (pos[string][point]));
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

  camera(0.0, -STRINGS*spacing/10, 50.0, // eyeX, eyeY, eyeZ
         0.0, STRINGS*spacing/2, 0.0, // centerX, centerY, centerZ
         0.0, 1.0, 0.0); // upX, upY, upZ

  // fix (freeze) the endpoints
  for(int string = 0; string < STRINGS; string++) {
    fixed[string][0] = true;
    fixed[string][POINTS-1] = true;
  }

  // initialize audio
  minim = new Minim(this);
  speaker = minim.getLineOut(Minim.STEREO, 512);
  mic = minim.getLineIn(Minim.MONO, 512);
  for(int string = 0; string < STRINGS; string++) {
    sounds[string] = new SpringSound(
      pos[string], // points
      fixed[string], // fixed points
      map(string, 0, STRINGS, 0.9, 0.01), // gain
      pow(pow(2, 1.0/1.0), string) * 0.05, // rate
      speaker.sampleRate()/mic.sampleRate() // sample ratio
      );
    speaker.addSignal(sounds[string]);
    mic.addListener(sounds[string]);
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
  k2 = map(mouseX, 0, width, 0.001, 0.1);
  physics();
  painting();
}

double sine(float phase) { return Math.sin(map(phase, 0, 1.0, 0, (float) Math.PI*2)); }
double saw(float phase) { return 2.0 * ((phase + 0.5) % 1.0 - 0.5); }
void keyPressed() {
  String toprow = "qwertyuiop";
  String letters = "asdfghjkl;";
  String numbers = "1234567890";
  if(numbers.indexOf(key) > -1) {
    for(int string = 0; string == 0; string++)
      for(int point = 1; point < POINTS-1; point++)
        pos[string][point] += 10*sine(map(point, 0, POINTS, 0, 1) * numbers.indexOf(key));
  } else if(toprow.indexOf(key) > -1) {
    for(int string = 0; string == 0; string++)
      for(int point = 1; point < POINTS-1; point++)
        pos[string][point] += 10*saw(map(point, 0, POINTS, 0, 1) * toprow.indexOf(key));
  } else if(letters.indexOf(key) > -1) {
    for(int string = 0; string == 0; string++)
      pos[string][(int) map(letters.indexOf(key), 0, letters.length(), 1, POINTS-1)] += 15;
  } else if(key == 'm') {
    for(int string = 0; string == 0; string++)
      sounds[string].usemic = !sounds[string].usemic;
  }
}

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

  private double interpolate(double a, double b, double frac) {
      return (b - a) * frac + a;
  }

  synchronized void generate(float[] left, float[] right) {
    for ( int i = 0; i < left.length; i += 1 ) {
      float samp = (float) (interpolate(points[(int) point],
                                        points[(((int) point) + 1) % points.length],
                                        point - (int) point)
                            / 50.0 * gain);
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
