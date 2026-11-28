// The oracle orb, ported from explore/orb.html.
const VS='attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}';
const NOISE=`
uniform vec3 pal[5];
float h(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float n(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
return mix(mix(mix(h(i),h(i+vec3(1,0,0)),f.x),mix(h(i+vec3(0,1,0)),h(i+vec3(1,1,0)),f.x),f.y),mix(mix(h(i+vec3(0,0,1)),h(i+vec3(1,0,1)),f.x),mix(h(i+vec3(0,1,1)),h(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){float a=.5,s=0.;for(int i=0;i<4;i++){s+=a*n(p);p*=2.03;a*=.5;}return s;}
vec3 spin(vec3 p,float a){float c=cos(a),s=sin(a);return vec3(c*p.x+s*p.z,p.y,-s*p.x+c*p.z);}
vec3 brand(float k){k=fract(k)*3.;vec3 m=pal[0],i=pal[1],c=pal[2];return k<1.?mix(m,i,k):k<2.?mix(i,c,k-1.):mix(c,m,k-2.);}`;

const FS_AURORA=`precision highp float;uniform vec2 res,look;uniform float t,fog,glow,R;uniform mat3 turn;${NOISE}
void main(){vec2 uv=(gl_FragCoord.xy*2.-res)/res.y;float r=length(uv)/R;vec3 col=vec3(0);float a=0.;
 float halo=exp(-max(r-1.,0.)*4.2)*(.34+.5*glow);vec3 hc=brand(atan(uv.y,uv.x)/6.283+t*.03);
 if(r<1.){vec2 q=uv/R;float z=sqrt(1.-r*r);vec3 N=vec3(q,z);
  vec3 inner=vec3(.015,.02,.045);float acc=0.;
  for(int i=0;i<14;i++){float d=(float(i)+.5)/14.;vec3 p=vec3(q*(1.-.16*z*d),z*(1.-2.*d));
   vec3 w=turn*p;
   float f=fbm(w*2.1+vec3(0.,t*.09,0.)+fbm(w*1.4-t*.05)*1.9);
   float den=smoothstep(.45,.78,f)*(1.-.4*dot(p,p));
   inner+=brand(f*1.5+w.y*.28+t*.025)*den*(1.-acc)*.34;acc+=den*.15;}
  inner*=1.+.55*glow;
  float core=exp(-r*r*5.)*(.22+.12*sin(t*1.3)+.35*glow);inner+=mix(pal[0],vec3(1.),.7)*core;
  inner=mix(inner,vec3(.3,.33,.39)*(.55+.7*fbm(spin(N,t*.07)*2.4)),fog*.86);
  float fres=pow(1.-z,2.6);inner+=brand(q.x*.22+q.y*.3+t*.04)*fres*.95*(1.-fog*.65);
  vec3 L=normalize(vec3(-.55+look.x*.2,.7+look.y*.2,.6));float sp=pow(max(dot(reflect(-L,N),vec3(0,0,1)),0.),60.);
  inner+=vec3(1.)*sp*.35;
  inner+=vec3(1.)*smoothstep(.2,0.,length((q-vec2(.34,-.62))*vec2(1.,2.6)))*.17;
  col=inner;a=1.;}
 float edge=smoothstep(1.012,.992,r);vec3 hcol=hc*(1.-fog*.7);
 vec3 outc=mix(hcol,col,edge);float outa=mix(halo*(1.-smoothstep(1.35,1.62,r)),1.,edge);
 gl_FragColor=vec4(outc*outa,outa);}`;

const FS_TAPE=`precision highp float;uniform vec2 res,look;uniform float t,fog,glow,R;uniform mat3 turn;${NOISE}
vec3 band(float f){return f<.40?pal[0]:f<.48?min(pal[0]*1.5,vec3(1.)):f<.545?pal[1]:f<.61?pal[2]:pal[3];}
float disc(vec2 uv,vec2 c,vec2 sq){return length((uv-c)/sq)/R;}
void main(){vec2 uv=(gl_FragCoord.xy*2.-res)/res.y;vec3 ink=pal[4];
 float wob=sin(t*3.2)*(.028+.03*glow);vec2 sq=vec2(1.+wob,1.-wob);
 float r=disc(uv,vec2(0.),sq);float ang=atan(uv.y,uv.x);r+=sin(ang*5.+t*2.4)*.006;
 vec4 o=vec4(0.);
 float sh=disc(uv,vec2(.07,-.085)-look*.075,sq);if(sh<1.05)o=vec4(ink*.34,.34);
 if(r<1.){vec2 q=uv/(R*sq);float z=sqrt(max(1.-dot(q,q),0.));
  vec3 p=turn*vec3(q,z);
  vec2 sw=vec2(fbm(p*1.5+t*.08),fbm(p*1.5+7.-t*.06));
  float f=fbm(p*1.7+vec3(sw*2.4,t*.1));
  vec3 c=band(f);
  vec2 g=gl_FragCoord.xy/(res.y/80.);mat2 rot=mat2(.8,.6,-.6,.8);vec2 cell=fract(rot*g)-.5;
  float shade=clamp(dot(q,vec2(.55,-.65))+.12,0.,1.);
  c=mix(c,ink,step(length(cell),shade*.62)*.62);
  c=mix(c,vec3(1.,.97,.9),glow*.28);
  vec3 cloud=fbm(spin(vec3(q,z),t*.18)*2.6)>.5?vec3(.82,.77,.68):vec3(.66,.6,.5);
  c=mix(c,mix(cloud,ink,step(length(cell),shade*.55)*.4),fog*.92);
  c=mix(c,mix(pal[1],vec3(1.),.4),step(.86,r)*step(q.y,-.3)*step(r,.92)*.9);
  o=vec4(c,1.);}
 float line=1.-smoothstep(.026,.034,abs(r-1.));o=mix(o,vec4(ink,1.),line);
 gl_FragColor=vec4(o.rgb*(o.a<1.&&line<.01?1.:1.),o.a);}`;
