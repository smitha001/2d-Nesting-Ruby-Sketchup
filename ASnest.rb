require 'clipper'
puts "ASnest"

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

def dcloop
	thedc = Sketchup.active_model.selection[0]
	afile = File.open('D:\Users\Anthony\Documents\acsvfile.csv')
	thecontents = afile.read.split(/\n/)
	allsets = []
	headings = thecontents[0].split(",")
	thecontents[1..-1].each do |l|
		eachset = {}
		l.split(",").each_with_index do |v, i|
			if v.numeric? then
				eachset[headings[i]] = v
			else
				eachset[headings[i]] = '"' + v + '"'
			end
		end
		allsets.push eachset
	end
	thedcdef = thedc.definition	
	allsets.each_with_index do |s, i|
		s.each do |k,v|
			thedcdef.set_attribute  'dynamic_attributes', k, v
			thedcdef.set_attribute  'dynamic_attributes', "_" + k + "_formula", v
		end
		dcs = $dc_observers.get_latest_class
		dcs.redraw_with_undo(thedc)
		keys = {
   :filename => "D:/Users/Anthony/Documents/" + i.to_s + ".jpg",
   :width => 640,
   :height => 480,
   :antialias => false,
   :compression => 0.9,
   :transparent => false
		}
		model = Sketchup.active_model
		view = model.active_view
		#model.active_view.refresh || Sketchup.active_model.active_view.invalidate
		view.write_image keys	
	end


	
end



module ASnest
	def self.almostequal(a, b, tolerance=0.000001)
		return ((a-b).abs < tolerance)
	end
	def self.intersects(a,b,c,d) #returns the intersection point of a-b and c-d if it exists
		ctoa = [a[0] - c[0], a[1] - c[1]]
		vatob = [b[0] - a[0], b[1] - a[1]]
		vctod = [d[0] - c[0],d[1] - c[1]]
		atoc = [c[0] - a[0], c[1] - a[1]]
		t = self.crossprod2d(ctoa, vatob) / self.crossprod2d(vctod, vatob)
		t2 = self.crossprod2d(atoc, vctod) / self.crossprod2d(vatob, vctod)
		if (t > 0) and (t < 1) then
			if (t2 > 0) and (t2 < 1) then
				ip = [a[0] + t * vatob[0], a[1] + t * vatob[1]]
				return ip
			end
		end
		return nil
	end
	def self.onsegment(a,b,p)
		vap = [p[0] - a[0], p[1] - a[1]]
		vbp = [p[0] - b[0], p[1] - b[1]]
		if self.vectorlengthzero(vap) or self.vectorlengthzero(vbp) #touching point a or b
			return false
		end
		if self.almostequal(self.crossprod2d(vap,vbp),0) #co-linear
			if self.dotprod2d(vap,vbp) < 0 then  #ap and bp point in opposite directions
				return true
			end
		end
		return false #not touching, not co-linear and inbetween a and b
	end
	def self.crossprod2d(a,b) #|a||b|sin(theta)u^
		return (a[0] * b[1] - a[1] * b[0])
	end
	def self.dotprod2d(a,b) # |a||b|cos(theta)
		return (a[0]*b[0] + a[1]*b[1])
	end
	def self.vectorlengthzero(v)
		return (self.almostequal(v[0],0.0) and almostequal(v[1],0.0))
	end
	def self.vectorlength2d(v)
		return (Math.sqrt(v[0]*v[0] + v[1]*v[1]))
	end
	def self.face_to_poly(f)
		c = Clipper::Clipper.new
		a = []
		a = f.loops.inject([]) do |ary, l|
			l.vertices.each {|v| ary.push([v.position[0]*25.4, v.position[1]*25.4])}
			ary
		end
		#puts a
		if c.orientation(a) then 
		#c.add_subject_polygon(a)
		#c.offset_polygons(a,5.5,Clipper::jtSquare,0)
			return a
		else
			return a.reverse
		end
	end
	def self.offset_polygons(polys, delta, joints)
		ret = Clipper::Clipper.new
		return ret.offset_polygons(polys, delta, joints)
	end
	def self.poly_to_face(polys)
	b = []
		polys.each do |p| 
			a = p.inject([]) do |ary, v|
				ary.push([v[0]/25.4,v[1]/25.4,0.0])
				ary
			end
			b.push(a)
		end
		return b
	end
	def self.poly_make_face(polys, numbers)
		res = self.poly_to_face(polys)
		res.each do |e|
			g = Sketchup.active_model.entities.add_group
			g.entities.add_face(e)
			if numbers then
				e.each_with_index do |t,i|
					g.entities.add_text(i.to_s, t)
				end
			end
		end
	end
	def self.offace(f,del)
		p = self.face_to_poly(f)
		os = self.offset_polygons([p], del, :jtRound)
		op = self.poly_to_face(os)
		op.each do |lop|
			Sketchup.active_model.entities.add_face lop
		end
	end
	def self.testrig()
		if Sketchup.active_model.selection[0].material != nil then
		a = Sketchup.active_model.selection[0]
		b = Sketchup.active_model.selection[1]
		else
		b = Sketchup.active_model.selection[0]
		a = Sketchup.active_model.selection[1]
		end
		apoly = face_to_poly(a)
		apoly.reverse!
		bpoly = face_to_poly(b)
		puts self.no_fit_polygon(apoly,bpoly,true,false)
	end
	def self.findinsidestartpoint(apoly,bpoly) #apparently there is no safe heuristic, so lets try a couple of things...
		sp = []
		#first up, will b's bounding box fit inside a's?
		ax = apoly.map {|a| a[0]}
		ay = apoly.map {|a| a[1]}
		maxa = [ax.max, ay.max]
		mina = [ax.min, ay.min]
		bx = bpoly.map {|b| b[0]}
		by = bpoly.map {|b| b[1]}
		maxb = [bx.max, by.max]
		minb = [bx.min, by.min]	
		puts "good start"		
		print maxa
		puts
		print mina
		if (maxb[0] - minb[0]) < (maxa[0] - mina[0]) then
			if (maxb[1] - minb[1]) > (maxa[1] - mina[1]) then
				return nil
			end
		else
			return nil
		end
		puts "step a"
		#lets try centre of bounding boxes, then project down (maybe left)
		bbca = [(maxa[0] + mina[0])/2, (maxa[1] + mina[1])/2]
		bbcb = [(maxb[0] + minb[0])/2, (maxb[1] + minb[1])/2]
		bnew = bpoly.map {|bpoint| [bbca[0] + bpoint[0] - bbcb[0], bbca[1] + bpoint[1] - bbcb[1]]}
		#confirm every vertex of b is inside a
		puts "bnew"
		print bnew
		puts
		vec = [0,-1]
		#move = self.projpolybtopolya(apoly,bnew,vec)
		moved = bnew.map{|b| b[1]}.min
		if polybinsidepolya(apoly,bnew) then 
			sp = [bbca[0] - bbcb[0], bbca[1]-bbcb[1] - moved]
		end
		puts "sp"
		print sp
		puts
		bpoly = bnew.clone
		return sp
	end
	def self.projpolybtopolya(a,b,v)
		#project each vertex of b in the v direction, project each vertex of a in the -ve v direction, 
		a.each_with_index do |apoint, i|
			nexti = (i == (a.length - 1)) ? 0 : i + 1
			anext = a[nexti]
			
		end
		return [0,0]
	end
	def self.polybinsidepolya(a,b)
		ax = a.map {|a| a[0]}
		ay = a.map {|a| a[1]}
		osa = [ax.max + 10.0, ay.max]
		thecount = []
		b.each_with_index do |bpoint,j|
			thecount[j] = 0
			a.each_with_index do |apoint,i|
				nexti = (i == (a.length - 1)) ? 0 : i+1
				anext = a[nexti]
				if self.almostequal(apoint[0],bpoint[0]) and self.almostequal(apoint[1],bpoint[1]) then
					thecount[j] = thecount[j] + 1
				else
					if self.intersects(apoint,anext,osa,bpoint) then
						thecount[j] = thecount[j] + 1
					end
				end
			end
		end
		puts "the count"
		print thecount
		res = thecount.map {|c| c.odd?}
		return res.all?
	end
	def self.no_fit_polygon(aorig,b,inside,searchedges)
		adata = {"orig" => aorig}
		bdata = {"poly" => b}
		if (aorig.length < 3 || b.length < 3)
			return nil
		end
		sl1 = []
		aminyindex = aorig.map {|e| e[1]}
		aminyindex = aminyindex.index(aminyindex.min)
		aminxindex = aorig.map {|e| e[0]}
		aminxindex = aminxindex.index(aminxindex.min)		
		adata["poly"] = aorig.map {|e| [e[0] - aorig[aminxindex][0], e[1] - aorig[aminyindex][1]]}		
		adata["offset_to_origin"] = [-aorig[aminyindex][0], -aorig[aminyindex][1]]
		a = adata["poly"]		
		bmaxyindex = b.map {|e| e[1]}
		bmaxyindex = bmaxyindex.index(bmaxyindex.max)
		startpoint = []
		if (not inside)
			startpoint = [a[aminyindex][0] - b[bmaxyindex][0], a[aminyindex][1] - b[bmaxyindex][1]] #the startpoint is the min y of a and the max y of b
		else
			startpoint = self.findinsidestartpoint(adata["poly"],b)
			puts "oh god no - i haven't done this bit" #searching an inside fit polygon
		end
		self.poly_make_face([a], true)
		bdata["os"] = startpoint.clone #offset is added to bpoly to make it contact apoly. NFP = array of each offset
		prevvector = nil
		nfp = []
		completeloop = nil
		while startpoint != nil do #the startpoint = nil if the inside placement fails....
			counter = 0
			while ((counter < (a.length + b.length+15)) and (completeloop == nil)) do #this needs to include a criteria about the offset point getting back to the startpoint...ie one orbit is complete
				counter = counter + 1
				touching = []
				vectors = []
				bospoly = b.map {|e| [e[0] + bdata["os"][0], e[1] + bdata["os"][1]]}
				bdata["bospoly"] = bospoly
				self.poly_make_face([bospoly],true)				
				a.each_with_index do |apoint, i| #a nested loop to catch all touching points
																					#poly b orbits polya in an anti-clockwise direction
																					#so possible movement here is either
																					#a[i] to a[nexti]     or     b[nextj] to b[j]
																					# if Vb[nextj]tob[j] falls within the arc between va[i]toa[nexti] and  va[i]toa[previ] then the translation is along va[i]toa[nexti] ...otherwise it's vb[nextj]tob[j]
					nexti = (i == a.length - 1) ? 0 : i+1
					bospoly.each_with_index do |bpoint, j|
						nextj = (j == bospoly.length - 1) ? 0 : j+1
						if (self.almostequal(apoint[0], bpoint[0])  and self.almostequal(apoint[1], bpoint[1])) # two vertices touching.....
							# if a is concave at this vertex....
							vacn = [a[nexti][0] - apoint[0], a[nexti][1] - apoint[1]]  #vector a current to a next
							previ = (i == 0) ? (a.length - 1) : i-1
							vacp =  [a[previ][0] - apoint[0], a[previ][1] - apoint[1]] #vector a current to a prev
							vl = self.vectorlength2d(vacn)
							uvacn = [vacn[0]/vl,vacn[1]/vl]
							vl = self.vectorlength2d(vacp)
							uvacp = [vacp[0]/vl,vacp[1]/vl]
							vbcn = [bospoly[nextj][0] - bpoint[0], bospoly[nextj][1] - bpoint[1]]
							#prevj = (j == 0) ? (j.length - 1) : j-1
							#vbcp = [b[prevj][0] - bpoint[0], b[prevj][1] - bpoint[1]]
							vl = self.vectorlength2d(vbcn)							
							uvbcn = [vbcn[0]/vl, vbcn[1]/vl]
							cpa = self.crossprod2d(uvacn, uvacp)
							cpb = self.crossprod2d(uvacn, uvbcn)
							cpc = self.crossprod2d(uvacp, uvbcn)
							if cpa <= 0  then #a corner is concave so uvacn
								vectors.push(uvacn)
							else
								#puts "i, j " + i.to_s + ", " + j.to_s
								#puts "cpa, cpb, cpc " + cpa.to_s + ", " + cpb.to_s + ", " + cpc.to_s
								if	cpb > 0 and cpc <0 and (not (self.almostequal(cpb,0.0))) and (not (self.almostequal(cpc,0.0))) then #is it inside does it go uvacn
									vectors.push(uvacn)
									#puts "p1"
								else
									if cpb < 0 then
										vectors.push(uvacn)
										#puts "p2"
									else
										vectors.push([-uvbcn[0],-uvbcn[1]])
										#puts "p3"
									end
								end
							end
							touching.push({"type" => 0, "a" => i, "b" => j})
						else
							puts " i,j " + i.to_s + ", " + j.to_s
							puts
							puts "apoint"
							print apoint
							puts
							print a[nexti]
							puts
							print bpoint
							if (self.onsegment(apoint,a[nexti],bpoint)) #a vertex on b touches a segment of a
								touching.push({"type" => 1, "a" => nexti, "b"=>j})
								v = [a[nexti][0]-apoint[0],a[nexti][1]-apoint[1]]
								vl = self.vectorlength2d(v)
								vectors.push([v[0]/vl,v[1]/vl])
								puts "b on a seg"
							else
								if (self.onsegment(bpoint, bospoly[nextj], apoint)) #a vertex on a touches a segment on b
									touching.push({"type" => 2, "a" => i, "b" => nextj})
									v = [bpoint[0]-bospoly[nextj][0],bpoint[1]-bospoly[nextj][1]]
									vl = self.vectorlength2d(v)
									vectors.push([v[0]/vl,v[1]/vl])									
									puts "a on b seg"
								end
							end
						end
					end
				end
				rwvectors = []
				rwvectors = self.eliminate_vectors(vectors)
				sl1 = self.polygon_slide(adata, bdata, rwvectors)
				nfp.push(sl1)
				bdata["os"] = [bdata["os"][0]+sl1[0], bdata["os"][1]+sl1[1]]
				#now go choose which vector based on shortest slide to intersect		
				if (self.almostequal(bdata["os"][0],startpoint[0]) and self.almostequal(bdata["os"][1],startpoint[1])) then
					completeloop = true
				end
			end
			startpoint = nil
		end
		#self.poly_make_face([nfp],false)
		a = [0,0,0]
		p = [0,0,0]
		puts "nfp"
		print nfp
		nfp.each do |v|
			a[0] = a[0] + v[0]/25.4
			a[1] = a[1] + v[1]/25.4
			a[2] = 0
			Sketchup.active_model.entities.add_line a, p
			p[0] = a[0]
			p[1] = a[1]
		end
		return "ended"
	end
	def self.eliminate_vectors(vectors)
		puts
		puts "vectors"
		print vectors
		exc = vectors.map {|e| true}
		norms = vectors.map {|v| [v[1], -v[0]]}
		vectors.each_with_index do |v, j|
			norms.each_with_index do |n, i|
				res = self.dotprod2d(v , n)
				if res < 0 then
					exc[j] = false
					next
				end
			end
		end
		return [vectors[exc.index(true)]]
	end
	def self.polygon_slide(adata, bdata, vectors)
		#puts "yay team"
		#puts vectors

		slide = []
		bospoly = bdata["bospoly"]
		posmove = []
		vectors.each do |v|
			cof = 0
			pt = []
			adata["poly"].each_with_index do |apoint,i|
				bospoly.each_with_index do |bpoint,j|
					#puts "first half i,j" + i.to_s + "," + j.to_s
					delta = []
					nextj = ((bospoly.length - 1) == j) ? 0: j+1
					bnext = bospoly[nextj]
					#does a line from apoint in the -ve v direction cross a segment of b and how far away
					# apoint + cof * v = bpoint + cof2 * v(from bpoint to bnext)
					#cof = ((bpoint - apoint)x v(from bpoint to bnext) )/ v x v(bpoint to bnext)
					vbtobn = [bnext[0] - bpoint[0], bnext[1] - bpoint[1]]
					#are v and vbtobn parallel?
					para = self.crossprod2d(v,vbtobn)
					if self.almostequal(para,0.0) then #they are parallel or anti parallel
						#are they co-linear?
						vbtoa = [apoint[0] - bpoint[0], apoint[1] - bpoint[1]]	
						col = self.crossprod2d(v,vbtoa)
						if self.almostequal(col,0.0) then #they are co-linear
							#if they are antiparallel, 
							if self.dotprod2d(v,vbtobn) < 0 then #so v and vbtobn are opposite sorta

								if self.onsegment(bpoint,bnext,apoint) then
									#idx = (v[0].abs > v[1].abs) ? 0 : 1
									#cof = (-bpoint[idx] + apoint[idx])
									#delta = [cof * v[0], cof * v[1]]
									delta = [-bnext[0] + apoint[0], -bnext[1] + apoint[1]] #did i fuck this up?
									#puts "i bet"
									#puts delta
									if self.almostequal(delta[0],0.0) and self.almostequal(delta[1],0.0) then
										delta = []
									end									
								else
									onb = (self.almostequal(apoint[0],bpoint[0]) and self.almostequal(apoint[1],bpoint[1]))
									onbn = (self.almostequal(apoint[0],bnext[0]) and self.almostequal(apoint[1],bnext[1]))
									if onb then
										#puts "yeah onb you idiot"
										#puts "i & j " + i.to_s + "," + j.to_s
										#print apoint
										#puts
										#print bpoint
										#puts
										
										#delta = []
										delta = [-vbtobn[0],-vbtobn[1]]
										#print delta
										#puts
									end
								end
							else #they are parallel,co-linear....a different a point will sort this
							end
						else #they are parallel, but not co-linear...no result here
						end
					else #they are not parallel, draw a line from a, in the 've v direction. if it crosses a segment of b, store delta = v(that intersection to apoint
						vatob = [-apoint[0] + bpoint[0], -apoint[1] + bpoint[1]]	
						cof = self.crossprod2d(vatob,vbtobn)/self.crossprod2d(v, vbtobn)
						if cof < 0 then
							vbtoa = [-bpoint[0] + apoint[0], -bpoint[1] + apoint[1]]
							cof2 = self.crossprod2d(vbtoa, v) / self.crossprod2d(vbtobn, v)
							if self.almostequal(cof2,0.0)  then #or self.almostequal(cof2,1)
							else
								if (cof2 > 0) and (cof2 <1) or self.almostequal(cof2,1.0) then
									#puts "gee"
									#puts "gee i,j " + i.to_s + ", " + j.to_s
									delta = [-cof * v[0], -cof * v[1]]
									#puts delta
									if self.almostequal(delta[0],0.0) and self.almostequal(delta[1],0.0) then
										delta = []
									end								
								end
							end
						end
					end
					if delta != [] then
						#puts "delta"
						#print delta
						#puts
						#puts"i,j " + i.to_s + ", " + j.to_s
						top2 = [apoint[0]/25.4, apoint[1]/25.4,0]
						pt2 = [top2[0] + delta[0]/25.4, top2[1] + delta[1]/25.4]
						#Sketchup.active_model.entities.add_line top2, pt2 
						posmove.push(delta)
					else
						#puts "didn't draw"
					end
				end
			end		
			#puts "second half"
			bospoly.each_with_index do |bpoint, j|
				adata["poly"].each_with_index do |apoint, i|
					delta = []
					nexti = (i == (adata["poly"].length - 1)) ? 0 : i+1
					anext = adata["poly"][nexti]
					#draw a line from every point on polygon b in the v direction, 
					vatoan = [anext[0] - apoint[0],anext[1]-apoint[1]]
					vbtoa = [apoint[0] - bpoint[0], apoint[1] - bpoint[1]]
					cof = self.crossprod2d(vbtoa, vatoan)
					div = self.crossprod2d(v,vatoan)
					
					if self.almostequal(div,0.0) then
						#parallel, already done
					else
						cof = cof/div

						if cof > 0 then
							vatob = [bpoint[0] - apoint[0], bpoint[1] - apoint[1]]
							cof2 = self.crossprod2d(vatob,v)/self.crossprod2d(vatoan,v)

							if (cof2 > 0) and (cof2 < 1) or self.almostequal(cof2,1.0) then #
								delta = [cof * v[0],cof*v[1]]
								#puts "or this"
								if self.almostequal(delta[0],0.0) and self.almostequal(delta[1],0.0) then
									delta = []
								end
							end
						end
					end
					if delta != [] then
						#puts "delta b"
						#print delta
						#puts
						#puts"i,j " + i.to_s + ", " + j.to_s					
						top2 = [bpoint[0]/25.4, bpoint[1]/25.4,0]
						pt2 = [top2[0] + delta[0]/25.4, top2[1] + delta[1]/25.4]
						#Sketchup.active_model.entities.add_line top2, pt2 
						#puts "drew " + i.to_s + " " + j.to_s		
						posmove.push(delta)
					else 
						#puts "didn't draw"
					end
				end
				#puts "posmove"
				#print posmove
				#puts
			end
		end
		puts "fini"
		whichmove = posmove.map {|e| self.vectorlength2d(e)}
		res = whichmove.index(whichmove.min)
		if res == nil then 
			return [0,0]
		else
			return posmove[res]
		end
	end
	def self.polygonslidedistance(adata ,bdata, direction, ignorenegative)
		aoffset = adata("offset")
		boffset = bdata("offset")
		dir = self.normalisevector2d(direction)
		normal = [dir[1], -dir[0]]
		reverse = [-dir[0], -dir[1]]
		bp = bdata("poly").clone + bdata("poly")[0]
		ap = adata("poly").clone + adata("poly")[0]
		bp.each do |edgeb|
			var mind = nil
			ap.each do |edgea|
				a1 = [edgea[0]+aoffset[0], edgea[1]+aoffset[1]]
				a2 = [edgea[0]+aoffset[0], edgea[1]+aoffset[1]]
				b1 = [edgea[0]+aoffset[0], edgea[1]+aoffset[1]]
				b2 = [edgea[0]+aoffset[0], edgea[1]+aoffset[1]]
				#if (almostequal(a1[0], a2[0]) and almostequal(a1[1],a2[1])) or (almostequal(b1[0],b2[0]) and almostequal(b1[1],b2[1]))) then
				#	next
				#end
				d = self.segementdistance(a1,a2,b1,b2,dir)
			end
		end
	end
	def self.normalisevector2d(v)
		l = Math.sqrt(v[0]*v[0] + v[1]*v[1])
		return ([v[0]/l, v[1]/l])
	end
end