var psys = {
	w: 800,
	h: 1000,
	minSize: 9,
	maxSize: 16,
	jitter: 10,
	particleCount: 1000,
	particles: [],

	Particle: function() {
		this.x = rand(psys.w);
		this.y = rand(psys.h);
		this.size = psys.minSize + rand(psys.maxSize - psys.minSize);
    
    this.size = psys.w / 150;

		this.color = 192 + rand(64);
	},


	init: function() {
  
		this.slide5 = document.getElementById('slide5');
		this.context = this.slide5.getContext('2d');

		psys.resize();
    
    setTimeout(function() {

		  window.ras = window.requestAnimationFrame ||
					window.WebkitRequestAnimationFrame ||
					window.MozRequestAnimationFrame;

		  for (var i = 0; i < psys.particleCount; i++) {
			  psys.particles.push(new psys.Particle());
		  }

	    psys.tick();
    }, 10);
	},


	tick: function() {
		psys.update();
 
		psys.draw();
	},


	update: function() {
		var jitter = psys.jitter;

    for (var i = 0; i < psys.particles.length; i++) {
			var p = psys.particles[i];

			if (p.x < 0 || p.y < 0 || p.x > psys.w || p.y > psys.h) {
				psys.particles[i] = new psys.Particle();
			}

			psys.particles[i].x += rand(jitter) - jitter/2 + .5;
			psys.particles[i].y += rand(jitter) - jitter/2 + .5;
		}
	},


	draw: function() {

		var context = psys.context;
		var slide5 = psys.slide5;

		psys.fade();
		for (var i = 0; i < psys.particles.length; i++) {
			var p = psys.particles[i];
			var c = p.color;
			context.fillStyle = 'rgb(' + c + ', ' + 0 + ', ' + 0 + ')';
			context.beginPath();
			context.arc(p.x, p.y, p.size, 0, 2*Math.PI, false);
			context.closePath();
			context.fill();
		}

    window.ras(psys.tick);
	},


	fade: function() {
		// fade
    var lastImage = psys.context.getImageData(0, 0, psys.w, psys.h);
    var pixelData = lastImage.data;

		var len = pixelData.length;
		for (i = 3; i < len; i += 4) {
		     pixelData[i] -= 6;
		}

		psys.context.putImageData(lastImage,0,0);
	},

	resize: function() {
    setTimeout(function() {
		psys.w = window.innerWidth;
		psys.h = window.innerHeight;
		psys.slide5.width = psys.w;
		psys.slide5.height = psys.h;
    }, 10);
	}
}

window.onload = function() {
	psys.init();
}


function rand(b) {
	return Math.floor(Math.random() * b);
}
