float LIQUID_WATER = 0;
float LIQUID_SLIME = 1;
float LIQUID_LAVA = 2;

float LIQUIDTYPE_CONVERSION[] = {-3. -4, -5};

float touchedliquidbrush;

void() startupWaterBrushes1 = {
	entity e, prev;
	float i;

	dprint("Starting up water brushes... ");

	e = find(world, liquidbrush, "1");
	if (e) liquidbrushfirst = e;
	while (e) {
		i++;
		e.solid = SOLID_NOT;
		e.movetype = MOVETYPE_NOCLIP;
		setorigin(e, e.origin);

		prev = e;
		e = find(e, liquidbrush, "1");
		if (e) {
			prev.nextliquidbrush = e;
			e.prevliquidbrush = prev;
		}

	}
	dprint3("found ", ftos(i), "\n");
};

void() startupWaterBrushes = {
	entity e, prev;
	float i;
	e = find(world, classname, "func_door");
	if (e) liquidbrushfirst = e;
	dprint("Starting up water brushes... ");
	while (e) {
		
		i++;
		//dprint2(ftos(i), "\n");
		e.solid = SOLID_NOT;
		e.movetype = MOVETYPE_NOCLIP;
		setorigin(e, e.origin);

		prev = e;
		e = find(e, classname, "func_door");
		if (e) {
			prev.nextliquidbrush = e;
			e.prevliquidbrush = prev;
		}

	}
	dprint3("found ", ftos(i), "\n");
};

void() entity_watercheck = {

	float ct = pointcontents2(self.origin);

	if (ct <= CONTENT_WATER){
		if (self.flags & FL_SWIM2 && self.health > 0) self.flags |= FL_FLY;

		
		if ((self.flags & FL_MONSTER && self.health <= 0) || self.classname == "gib") {
			if (!self.gravity) self.gravity = 1;
			if (self.gravity > 0.05) {
				self.velocity *= 0.05/self.gravity; // reduces velocity when hitting water
			}
			self.gravity = 0.05;
		}

		self.flags |= FL_INWATER;

		self.waterlevel = 1;

		// Setting watertype here for standard liquid volumes
		// conflicts with the engine content check later on the same frame,
		// causing a spam of splash sounds
		if (!touchedliquidbrush)
			self.watertype = ct;
	}
	else {
		if (self.flags & FL_SWIM2) self.flags &~= FL_FLY;

		if (self.flags & (FL_INWATER | FL_INLIQUIDBRUSH) == FL_INWATER | FL_INLIQUIDBRUSH){
			sound (self, CHAN_AUTO, "misc/h2ohit1.wav", 1, ATTN_NORM);
		}

		if (self.flags & FL_MONSTER && self.health <= 0) {
			if (self.flags & FL_INWATER) {
				self.gravity = 1;
			}
		}

		self.flags &~= FL_INWATER;

		// same logic as the engine code. It's weird but that's how it is
		self.waterlevel = ct;

		self.watertype = CONTENT_EMPTY;
	}

	if (touchedliquidbrush) self.flags |= FL_INLIQUIDBRUSH;
	else self.flags &~= FL_INLIQUIDBRUSH;
	
}

void() checkClientInWaterBrush = {
	entity e;
	float lvl;
	float prevlvl = self.waterlevel;
	
	e = liquidbrushfirst;

	while (e) {
		lvl = getWaterLevelFromBrush(self, e);
		if (lvl) {
			if (self.movetype != MOVETYPE_NOCLIP) {
				self.waterlevel = lvl;

				if (e.liquidtype == LIQUID_LAVA) self.watertype = CONTENT_LAVA;
				else if (e.liquidtype == LIQUID_SLIME) self.watertype = CONTENT_SLIME;
				else self.watertype = CONTENT_WATER;
			}
			//self.flags |= FL_INWATER;

			float dens;
			vector cl;

			//if !(self.flags & FL_INLIQUIDBRUSH)
			//	self.prevgravity = self.gravity;

			if (e.liquidtype == LIQUID_SLIME) {cl = '0 25 5'; dens = 150;}
			else if (e.liquidtype == LIQUID_LAVA) {cl = '255 80 0'; dens = 150;}
			else {cl = '130 80 50'; dens = 128;}

			if (e.liquidcolor) cl = e.liquidcolor;
			if (e.liquiddensity) dens = e.liquiddensity;

			if (lvl >= 2) self.gravity = 0.000001;
			else self.gravity = 1;

			if (lvl >= 3){
				csf_set(self, dens, cl, 70);
			}
			else {
				csf_clear(self, 70);
			}

			self.flags |= FL_INLIQUIDBRUSH;

			return;
		}

		e = e.nextliquidbrush;
	}

	// if the code came up to here, it means no liquid brush was touched in this frame,
	// so turn off everything if the entity was in one at the previous frame
	if (self.flags & FL_INLIQUIDBRUSH) {
		csf_clear(self, 70);
		self.gravity = 1;
		//self.watertype = CONTENT_EMPTY;
		//self.waterlevel = 0;

		self.flags &~= FL_INLIQUIDBRUSH;
	}
}

float(vector org) pointcontents2 = {
	touchedliquidbrush = FALSE;

	float pc = pointcontents(org);

	if (pc != CONTENT_EMPTY) return pc;

	float touched;

	entity e = liquidbrushfirst;
	while (e) {
		pointcontentchecks++;
		//if (pointcontentchecks % 500 == 0)
		//	dprint3("Checked ", ftos(pointcontentchecks), " point contents\n");

		
		if (org_x > e.absmax_x) 
			touched = 0;
		else if (org_x < e.absmin_x)
			touched = 0;
		else if (org_y > e.absmax_y)
			touched = 0;
		else if (org_y < e.absmin_y)
			touched = 0;
		else if (org_z > e.absmax_z)
			touched = 0;
		else if (org_z < e.absmin_z)
			touched = 0;
		else 
			touched = 1;
		
		//touched = getTouch(org, e);
		
		if (touched) {
			touchedliquidbrush = TRUE;

			//if (e.liquidtype == LIQUID_LAVA) return CONTENT_LAVA;
			//else if (e.liquidtype == LIQUID_SLIME) return CONTENT_SLIME;
			//else return CONTENT_WATER;
			
			return LIQUIDTYPE_CONVERSION[e.liquidtype];
		}

		e = e.nextliquidbrush;
	}
	return CONTENT_EMPTY;
}

// tests an entity against a water brush
float (entity e, entity brush) getWaterLevelFromBrush = {
	// same method as the engine's internal function:
	// - horizontal axes checked against entity's origin
	// - vertical axis checked against entity's bottom limit and view_ofs 
	if (e.origin_x > brush.absmax_x) 
		return 0;
	if (e.origin_x < brush.absmin_x)
		return 0;
	if (e.origin_y > brush.absmax_y)
		return 0;
	if (e.origin_y < brush.absmin_y)
		return 0;
	if (e.absmin_z > brush.absmax_z)
		return 0;
	if (e.absmax_z - e.view_ofs_z < brush.absmin_z)
		return 0;
	
	
	float lvl;
	float depth = brush.absmax_z - e.absmin_z;

	if (depth > (e.view_ofs_z - e.mins_z + 2))
		lvl = 3;
	else if (depth > (e.absmax_z - e.absmin_z)/2) {
		lvl = 2;
	}
	else lvl = 1;
	//dprint3("Applied waterlevel: ", ftos(lvl), "\n");
	return lvl;
};

// tests a point coordinate against an entity bbox
float (vector org, entity e) getTouch = {
	if (org_x > e.absmax_x) 
		return 0;
	if (org_x < e.absmin_x)
		return 0;
	if (org_y > e.absmax_y)
		return 0;
	if (org_y < e.absmin_y)
		return 0;
	if (org_z > e.absmax_z)
		return 0;
	if (org_z < e.absmin_z)
		return 0;

	return 1;
}

vector() WaterTest2 =
{
	if (self.movetype == MOVETYPE_NOCLIP)
		return VEC_ORIGIN;
		
	float wl = 0;
	float wt = 0;
	float wp;
	
	// iw -- fix waterlevel detection
	vector waist;

	// this is how the engine calculates the player's waist height (see
	// the "SV_CheckWater" function in "sv_phys.c")
	waist = self.origin;
	waist_z += (self.mins_z + self.maxs_z) * 0.5;

	//wp = pointcontents(self.origin);
	wp = pointcontents(waist);
	// iw -- END
	if (wp < -2 && wp > -6)
	{
		wl += 1;
		wt = min(wt,wp);
	}
	wp = pointcontents(self.origin + self.mins);
	if (wp < -2 && wp > -6)
	{
		wl += 1;
		wt = min(wt,wp);
	}
	wp = pointcontents(self.origin + self.maxs);
	if (wp < -2 && wp > -6)
	{
		wl += 1;
		wt = min(wt,wp);
	}
	wp = pointcontents(self.origin + self.view_ofs);
	if (wp < -2 && wp > -6)
	{
		wl += 1;
		wt = min(wt,wp);
	}
	
	return Vector(min(3,wl),wt,0);
}