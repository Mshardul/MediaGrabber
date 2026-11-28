// The oracle orb, ported from explore/orb.html.
const rnd=i=>{const x=Math.sin(i*91.7+13.1)*43758.5;return x-Math.floor(x)};

// Colours come from the chosen palette's tokens, so each look has its own orb.
let colours={};
const WHITE=[255,255,255],BLACK=[0,0,0];
function tokenColour(name){const value=getComputedStyle(document.documentElement).getPropertyValue(name).trim();
 if(!/^#[0-9a-f]{6}$/i.test(value))console.error(name+' is not a six-digit colour: '+value);
 return [1,3,5].map(i=>parseInt(value.slice(i,i+2),16)||0)}
function readColours(){colours={a:tokenColour('--orb-a'),b:tokenColour('--orb-b'),c:tokenColour('--orb-c'),light:tokenColour('--orb-light'),ink:tokenColour('--orb-ink')}}
const blend=(from,to,k)=>from.map((v,i)=>Math.round(v+(to[i]-v)*k));
const css=(rgb,alpha=1)=>`rgba(${rgb.join(',')},${alpha})`;
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
const painters={};
function painterFor(style){if(style in painters)return painters[style];
 const canvas=document.createElement('canvas'),g=canvas.getContext('webgl',{premultipliedAlpha:style==='aurora'});
 if(!g){console.error('WebGL is not available, so the orb cannot be drawn');return painters[style]=null}
 const shader=(type,source)=>{const s=g.createShader(type);g.shaderSource(s,source);g.compileShader(s);if(!g.getShaderParameter(s,g.COMPILE_STATUS))console.error(g.getShaderInfoLog(s));return s};
 const p=g.createProgram();g.attachShader(p,shader(g.VERTEX_SHADER,VS));g.attachShader(p,shader(g.FRAGMENT_SHADER,style==='aurora'?FS_AURORA:FS_TAPE));g.linkProgram(p);
 if(!g.getProgramParameter(p,g.LINK_STATUS)){console.error(g.getProgramInfoLog(p));return painters[style]=null}
 g.useProgram(p);g.bindBuffer(g.ARRAY_BUFFER,g.createBuffer());g.bufferData(g.ARRAY_BUFFER,new Float32Array([-1,-1,3,-1,-1,3]),g.STATIC_DRAW);
 const at=g.getAttribLocation(p,'p');g.enableVertexAttribArray(at);g.vertexAttribPointer(at,2,g.FLOAT,false,0,0);
 const u={};for(const name of ['res','look','t','fog','glow','R','turn','pal'])u[name]=g.getUniformLocation(p,name);
 return painters[style]={canvas,g,u}}

class Orb{
 constructor(el,style){this.el=el;this.style=style;this.mood=el.dataset.mood;this.look=[0,0];this.aim=[0,0];this.pos=[0,0];this.vel=[0,0];this.fog=0;this.glow=0;this.search=0;this.swirl=0;this.clock=rnd(this.style.length)*20;
  this.back=document.createElement('canvas');this.ball=document.createElement('canvas');this.fx=document.createElement('canvas');el.replaceChildren(this.back,this.ball,this.fx);this.bctx=this.back.getContext('2d');this.ballctx=this.ball.getContext('2d');this.ctx=this.fx.getContext('2d');this.yaw=0;this.pitch=0;
  }
 follow(x,y,box){const o=this.el.getBoundingClientRect(),cx=o.x+o.width/2,cy=o.y+o.height/2,clamp=v=>Math.max(-1,Math.min(1,v));
  // Scaled to the room on each side, so every edge of the box is a full lean.
  this.aim=[clamp((x-cx)/Math.max(1,x<cx?cx-box.left:box.right-cx)),clamp((cy-y)/Math.max(1,y<cy?box.bottom-cy:cy-box.top))];}
 draw(dt){const painter=painterFor(this.style);if(!painter)return;const{g,u,canvas}=painter,still=reduced.matches,tape=this.style==='tape';
  const speed={waiting:1,resting:.4,clouded:.35,drag:2.6,searching:2.4}[this.mood];
  this.search+=((this.mood==='searching'?1:0)-this.search)*(still?1:Math.min(1,dt*3));if(!still)this.swirl+=dt*2.2*this.search;if(!still)this.clock+=dt*speed;
  const ease=still?1:Math.min(1,dt*4);
  this.fog+=((this.mood==='clouded'?1:0)-this.fog)*ease;this.glow+=((this.mood==='drag'?1:0)-this.glow)*ease;
  const aim=still?[0,0]:this.aim;this.look=this.look.map((v,i)=>v+(aim[i]-v)*ease);
  const t=still?6.4:tape?Math.floor(this.clock*12)/12:this.clock;
  const size=this.el.clientWidth,d=Math.min(devicePixelRatio,2),px=Math.round(size*d);
  for(const cv of [this.back,this.ball,this.fx])if(cv.width!==px||cv.height!==px){cv.width=cv.height=px}
  const near=still?0:Math.max(0,1-Math.hypot(...this.look))*(this.hover?1:0);
  const R=.56*(1+(still?0:Math.sin(t*1.15)*.012*(this.mood==='waiting'?1.6:1))+this.glow*.07+near*.045);
  // Idle spin around the upright axis, plus the pointer turning the ball towards itself.
  this.yaw=(tape?.42:.2)*t-this.look[0]*1.25;this.pitch=.28+this.look[1]*.95;
  const cy=Math.cos(this.yaw),sy=Math.sin(this.yaw),cp=Math.cos(this.pitch),sp=Math.sin(this.pitch);
  this.m=[cy,0,sy, sp*sy,cp,-sp*cy, -cp*sy,sp,cp*cy];
  if(canvas.width!==px||canvas.height!==px)canvas.width=canvas.height=px;g.viewport(0,0,px,px);g.uniform2f(u.res,px,px);g.uniform3fv(u.pal,[colours.a,colours.b,colours.c,colours.light,colours.ink].flat().map(v=>v/255));g.uniform2f(u.look,...this.look);g.uniform1f(u.t,t);g.uniform1f(u.fog,this.fog);g.uniform1f(u.glow,this.glow);g.uniform1f(u.R,R);g.uniformMatrix3fv(u.turn,false,this.m);g.drawArrays(g.TRIANGLES,0,3);this.ballctx.clearRect(0,0,px,px);this.ballctx.drawImage(canvas,0,0);
  const lift=still?0:Math.sin(t*(tape?2.1:.9))*size*.012;
  // A spring: Tape Deck overshoots and bounces, Aurora glides.
  const[stiff,drag]=tape?[150,11]:[70,15];
  this.pos=this.pos.map((p,i)=>{if(still)return 0;this.vel[i]+=((aim[i]*size*.13-p)*stiff-this.vel[i]*drag)*dt;return p+this.vel[i]*dt});
  for(const cv of [this.back,this.ball,this.fx])cv.style.transform=`translate(${this.pos[0]}px,${lift-this.pos[1]}px)`;
  const c=this.ctx;c.setTransform(d,0,0,d,0,0);c.clearRect(0,0,size,size);const mid=size/2,rad=size*R/2;
  const b=this.bctx;b.setTransform(d,0,0,d,0,0);b.clearRect(0,0,size,size);
  this.contents(c,t,mid,rad,tape);this.glass(c,mid,rad,tape);this.orbit(c,b,t,mid,rad,tape);}
 // Object space to screen space: the same turn the shader undoes.
 view([x,y,z]){const m=this.m;return[m[0]*x+m[1]*y+m[2]*z,m[3]*x+m[4]*y+m[5]*z,m[6]*x+m[7]*y+m[8]*z]}
 contents(c,t,mid,rad,tape){c.save();c.beginPath();c.arc(mid,mid,rad*.95,0,7);c.clip();
  const n=SYMBOLS.length;
  const items=SYMBOLS.map((symbol,i)=>{
   // Filled through the whole volume, not laid on the surface.
   const h=1-2*(i+.5)/n,flat=Math.sqrt(1-h*h),around=i*2.39996+t*(.04+rnd(i+1)*.05)*(i%2?1:-1)+this.swirl*(.8+rnd(i+31)*.4),depthIn=.26+.54*Math.cbrt(rnd(i+11));
   // Each one also drifts on its own slow loop in all three directions.
   const drift=k=>Math.sin(t*(.32+rnd(i+k)*.35)+rnd(i+k+2)*6.28)*.11;
   const at=this.view([Math.cos(around)*flat*depthIn+drift(13),h*depthIn+drift(17),Math.sin(around)*flat*depthIn+drift(19)]);
   const life=.5+.5*Math.sin(t*(.36+rnd(i+9)*.3)+i*2.7);
   return{i,symbol,at,alpha:Math.max(0,Math.min(1,life*1.7-.1))}}).sort((p,q)=>p.at[2]-q.at[2]);
  for(const m of items){const[x,y,z]=m.at,persp=1/(1-z*.38),depth=Math.max(0,Math.min(1,(z+.8)/1.6)),pull=this.glow*.45;
   const px=mid+x*persp*rad*.88*(1-pull),py=mid-y*persp*rad*.88*(1-pull)-this.glow*rad*.26,s=rad*(.045+.075*depth*depth+.015*rnd(m.i+21))*persp;
   c.save();c.translate(px,py);c.rotate(Math.sin(t*(.3+rnd(m.i+23)*.4)+m.i)*.38);
   // A slow tumble about its own axis, never fully edge on.
   c.scale(.62+.38*Math.abs(Math.cos(t*(.25+rnd(m.i+25)*.35)+m.i*1.7)),1);
   c.globalAlpha=m.alpha*(.16+.84*depth*depth)*(1-this.fog*.88);
   this.symbol(c,s,m.symbol,tape,depth);c.restore();}
  c.restore();}
 // Reflections drawn over the symbols, so they read as being behind the glass.
 glass(c,mid,rad,tape){const lx=this.look[0]*rad*.07,ly=-this.look[1]*rad*.07,spot=(x,y,rx,ry,turn,fill)=>{c.save();c.translate(mid+x*rad+lx,mid+y*rad+ly);c.rotate(turn);c.scale(rx*rad,ry*rad);c.beginPath();c.arc(0,0,1,0,7);c.restore();c.fillStyle=fill;c.fill()};
  c.save();c.globalAlpha=1-this.fog*.6;
  if(tape){spot(-.44,-.5,.23,.1,-.65,'rgba(255,252,242,.93)');spot(-.12,-.74,.05,.05,0,'rgba(255,252,242,.95)')}
  else{c.save();c.beginPath();c.arc(mid,mid,rad*.99,0,7);c.clip();
   const veil=c.createRadialGradient(mid+lx,mid+ly,rad*.45,mid,mid,rad);veil.addColorStop(0,css(BLACK,0));veil.addColorStop(.78,css(blend(colours.b,BLACK,.4),.08));veil.addColorStop(1,css(blend(colours.a,WHITE,.7),.3));c.fillStyle=veil;c.fillRect(mid-rad,mid-rad,rad*2,rad*2);
   const sheen=c.createLinearGradient(mid,mid-rad,mid,mid);sheen.addColorStop(0,'rgba(255,255,255,.13)');sheen.addColorStop(1,'rgba(255,255,255,0)');spot(-.06,-.56,.66,.36,-.12,sheen);
   const dot=c.createRadialGradient(mid-rad*.4+lx,mid-rad*.5+ly,0,mid-rad*.4+lx,mid-rad*.5+ly,rad*.13);dot.addColorStop(0,'rgba(255,255,255,.95)');dot.addColorStop(1,'rgba(255,255,255,0)');spot(-.4,-.5,.13,.13,0,dot);
   c.restore()}
  c.restore()}
 symbol(c,s,{path,solid},tape,depth){c.scale(s/10,s/10);c.translate(-12,-12);c.lineCap=c.lineJoin='round';
  // Deeper symbols take the colour of what surrounds them.
  const mix=(a,b)=>`rgb(${a.map((v,k)=>Math.round(v+(b[k]-v)*depth)).join(',')})`;
  if(tape){const line=mix(colours.a,colours.light);c.strokeStyle=mix(blend(colours.a,BLACK,.22),colours.ink);c.lineWidth=3+2*depth;c.stroke(path);if(solid){c.fillStyle=line;c.fill(path)}c.strokeStyle=line;c.lineWidth=2;c.stroke(path)}
  else{const line=mix(blend(colours.a,colours.b,.5),blend(colours.a,WHITE,.92));c.shadowColor=css(blend(colours.a,WHITE,.5),.9);c.shadowBlur=s*(1.5-.9*depth);c.strokeStyle=line;c.lineWidth=1.2+.7*depth;c.stroke(path);if(solid){c.globalAlpha*=.55;c.fillStyle=line;c.fill(path)}}}

 // Rings and lights circle in 3D: the far half is drawn behind the sphere, the near half in front.
 orbit(front,back,t,mid,rad,tape){const dim=1-this.fog*.75,screen=p=>{const v=this.view(p),k=1/(1-v[2]*.16);return[mid+v[0]*rad*k,mid-v[1]*rad*k,v[2],k]};
  const ring=(radius,tilt,color,width)=>{let prev=null;for(let i=0;i<=96;i++){const a=i/96*Math.PI*2,x=Math.cos(a)*radius,z=Math.sin(a)*radius;
    const q=screen([x,z*Math.sin(tilt),z*Math.cos(tilt)]);
    if(prev){const near=(q[2]+prev[2])/2>0,c=near?front:back;c.beginPath();c.moveTo(prev[0],prev[1]);c.lineTo(q[0],q[1]);c.globalAlpha=(near?.85:.4)*dim;
     if(tape){c.strokeStyle=css(colours.ink);c.lineWidth=width*q[3]+2.5;c.stroke()}c.strokeStyle=color;c.lineWidth=width*q[3];c.stroke()}
    prev=q}};
  ring(1.27,.22,tape?css(colours.b):css(colours.a,.75),tape?3.5:1.2);
  ring(1.42,-.62,tape?css(colours.c):css(colours.b,.55),tape?2:.8);
  const count=tape?9:26;
  for(let i=0;i<count;i++){const h=(rnd(i+4)-.5)*1.5,a=t*(.1+rnd(i)*.2)*(i%2?1:-1)+i*2.4,d=1.22+rnd(i+2)*.42-this.glow*.3*((t*.5+rnd(i))%1);
   const q=screen([Math.cos(a)*d,h,Math.sin(a)*d]),near=q[2]>0,c=near?front:back,shine=.5+.5*Math.sin(t*1.6+i);
   c.globalAlpha=(near?1:.5)*dim*(.35+.65*shine);
   if(tape){const r=rad*.075*q[3]*(.55+.45*shine+this.glow*.3);c.beginPath();for(let j=0;j<8;j++){const w=j*Math.PI/4,l=j%2?r*.3:r;c.lineTo(q[0]+Math.cos(w)*l,q[1]+Math.sin(w)*l)}c.closePath();
    c.fillStyle=css([colours.b,colours.c,colours.a][i%3]);c.strokeStyle=css(colours.ink);c.lineWidth=1.6;c.fill();c.stroke()}
   else{c.beginPath();c.arc(q[0],q[1],(1+rnd(i+5)*1.8)*q[3],0,7);c.fillStyle=css([colours.a,colours.b,colours.c][i%3]);c.fill()}}
  // While searching, a bright point sweeps each ring with a short tail.
  if(this.search>.02)[[1.27,.22],[1.42,-.62]].forEach(([radius,tilt],r)=>{for(let k=0;k<30;k++){const a=1.1+r*2.6+this.swirl*(r?-1.5:1.9)-(r?-1:1)*k*.05,x=Math.cos(a)*radius,z=Math.sin(a)*radius,q=screen([x,z*Math.sin(tilt),z*Math.cos(tilt)]),c=q[2]>0?front:back;
    c.globalAlpha=this.search*Math.pow(1-k/30,1.4)*(q[2]>0?1:.55);c.shadowColor=css(colours.a);c.shadowBlur=tape||k>8?0:16;c.beginPath();c.arc(q[0],q[1],(tape?10:7.5)*(1-k/38)*q[3],0,7);c.fillStyle=tape?css(colours.c):css(blend(colours.a,WHITE,.85));c.fill();c.shadowBlur=0;if(tape&&!k){c.strokeStyle=css(colours.ink);c.lineWidth=2;c.stroke()}}});
  front.globalAlpha=back.globalAlpha=1}
}

(() => {
  let orbs = [];
  function build() {
    readColours();
    const style = document.documentElement.dataset.theme === "tapedeck" ? "tape" : "aurora";
    orbs = [...document.querySelectorAll(".orb")].map((el) => {
      if (!painterFor(style)) {
        el.textContent = "This browser cannot draw the 3D orb.";
        return null;
      }
      return new Orb(el, style);
    }).filter(Boolean);
  }

  // The pointer is tracked across the whole app window around each orb.
  function track() {
    document.querySelectorAll(".window").forEach((area) => {
      const inside = () => orbs.filter((orb) => area.contains(orb.el));
      area.addEventListener("pointermove", (event) => {
        inside().forEach((orb) => {
          orb.hover = true;
          orb.follow(event.clientX, event.clientY, area.getBoundingClientRect());
        });
      });
      area.addEventListener("pointerleave", () => {
        inside().forEach((orb) => {
          orb.hover = false;
          orb.aim = [0, 0];
        });
      });
    });
  }

  let last = performance.now();
  function tick(now) {
    const dt = Math.max(0, Math.min((now - last) / 1000, 0.05));
    last = now;
    if (!document.hidden) {
      orbs.forEach((orb) => {
        const box = orb.el.getBoundingClientRect();
        if (box.bottom > 0 && box.top < innerHeight) orb.draw(dt);
      });
    }
    requestAnimationFrame(tick);
  }

  document.addEventListener("DOMContentLoaded", () => {
    build();
    track();
    new MutationObserver(build).observe(document.documentElement, {
      attributeFilter: ["data-theme", "data-palette"],
    });
    requestAnimationFrame(tick);
  });
})();
