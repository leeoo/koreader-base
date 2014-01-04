local ffi = require("ffi")

local dummy = require("ffi/koptcontext_h")
local leptonica = ffi.load("libs/liblept.so.3")
local k2pdfopt = ffi.load("libs/libk2pdfopt.so.2")

local KOPTContext = {}
local KOPTContext_mt = {__index={}}

function KOPTContext_mt.__index:setBBox(x0, y0, x1, y1) self.bbox.x0, self.bbox.y0, self.bbox.x1, self.bbox.y1 = x0, y0, x1, y1 end
function KOPTContext_mt.__index:setTrim(trim) self.trim = trim end
function KOPTContext_mt.__index:setWrap(wrap) self.wrap = wrap end
function KOPTContext_mt.__index:setIndent(indent) self.indent = indent end
function KOPTContext_mt.__index:setRotate(rotate) self.rotate = rotate end
function KOPTContext_mt.__index:setColumns(columns) self.columns = columns end
function KOPTContext_mt.__index:setDeviceDim(w, h) self.dev_width, self.dev_height = w, h end
function KOPTContext_mt.__index:setDeviceDPI(dpi) self.dev_dpi = dpi end
function KOPTContext_mt.__index:setStraighten(straighten) self.straighten = straighten end
function KOPTContext_mt.__index:setJustification(justification) self.justification = justification end
function KOPTContext_mt.__index:setWritingDirection(direction) self.writing_direction = direction end
function KOPTContext_mt.__index:setMargin(margin) self.margin = margin end
function KOPTContext_mt.__index:setZoom(zoom) self.zoom = zoom end
function KOPTContext_mt.__index:setQuality(quality) self.quality = quality end
function KOPTContext_mt.__index:setContrast(contrast) self.contrast = contrast end
function KOPTContext_mt.__index:setDefectSize(defect_size) self.defect_size = defect_size end
function KOPTContext_mt.__index:setLineSpacing(line_spacing) self.line_spacing = line_spacing end
function KOPTContext_mt.__index:setWordSpacing(word_spacing) self.word_spacing = word_spacing end
function KOPTContext_mt.__index:setLanguage(language) self.language = ffi.cast("char*", language) end

function KOPTContext_mt.__index:setDebug() self.debug = 1 end
function KOPTContext_mt.__index:setCJKChar() self.cjkchar = 1 end
function KOPTContext_mt.__index:setPreCache() self.precache = 1 end

function KOPTContext_mt.__index:getTrim() return self.trim end
function KOPTContext_mt.__index:getZoom() return self.zoom end
function KOPTContext_mt.__index:getWrap() return self.wrap end
function KOPTContext_mt.__index:isPreCache() return self.precache end
function KOPTContext_mt.__index:getLanguage() return ffi.string(self.language) end
function KOPTContext_mt.__index:getPageDim() return self.page_width, self.page_height end
function KOPTContext_mt.__index:getBBox(x0, y0, x1, y1) return self.bbox.x0, self.bbox.y0, self.bbox.x1, self.bbox.y1 end

function KOPTContext_mt.__index:copyDestBMP(src)
	if src.dst.bpp == 8 or src.dst.bpp == 32 then
		k2pdfopt.bmp_copy(self.dst, src.dst)
	end
end

function KOPTContext_mt.__index:getWordBoxes(x, y, w, h, box_type)
	local box = ffi.new("BOX[1]")
	local boxa = ffi.new("BOXA[1]")
	local nai = ffi.new("NUMA[1]")
	local max_val = ffi.new("float[1]")
	local last_index = ffi.new("int[1]")
	local counter_l = ffi.new("int[1]")
	local nr_line, nr_word, current_line
	local counter_w, counter_cw
	local l_x0, l_y0, l_x1, l_y1

	if box_type == 0 then
	    k2pdfopt.k2pdfopt_get_reflowed_word_boxes(self, self.dst,
	    	ffi.new("int", x), ffi.new("int", y), ffi.new("int", w), ffi.new("int", h))
	    boxa = self.rboxa
	    nai = self.rnai
	elseif box_type == 1 then
	    k2pdfopt.k2pdfopt_get_native_word_boxes(self, self.dst,
	    	ffi.new("int", x), ffi.new("int", y), ffi.new("int", w), ffi.new("int", h))
	    boxa = self.nboxa
	    nai = self.nnai
	end
	
	if boxa == nil or nai == nil then return end

	--get number of lines in this area
	leptonica.numaGetMax(nai, max_val, last_index)
	local nr_line = max_val[0]
	--get number of lines in this area
	local nr_word = leptonica.boxaGetCount(boxa)
	assert(nr_word == leptonica.numaGetCount(nai))
	
	local boxes = {}
	counter_w = 0
	while counter_w < nr_word do
		leptonica.numaGetIValue(nai, counter_w, counter_l)
		current_line = counter_l[0]
		--sub-table that contains words in a line
		local lbox = {}
		boxes[counter_l[0]+1] = lbox
		counter_cw = 0
		l_x0, l_y0, l_x1, l_y1 = 9999, 9999, 0, 0
		while current_line == counter_l[0] and counter_w < nr_word do
			box = leptonica.boxaGetBox(boxa, counter_w, ffi.C.L_CLONE)
			--update line box
			l_x0 = box.x < l_x0 and box.x or l_x0
			l_y0 = box.y < l_y0 and box.y or l_y0
			l_x1 = box.x + box.w > l_x1 and box.x + box.w or l_x1
			l_y1 = box.y + box.h > l_y1 and box.y + box.h or l_y1
			-- box for a single word
			lbox[counter_cw+1] = {
				x0 = box.x, y0 = box.y,
				x1 = box.x + box.w,
				y1 = box.y + box.h,
			}
			counter_w, counter_cw = counter_w + 1, counter_cw + 1
			if counter_w < nr_word then
				leptonica.numaGetIValue(nai, counter_w, counter_l)
			end
		end
		if current_line ~= counter_l[0] then counter_w = counter_w - 1 end
		-- box for a whole line
		lbox.x0, lbox.y0, lbox.x1, lbox.y1 = l_x0, l_y0, l_x1, l_y1
		counter_w = counter_w + 1
	end
	return boxes
end

function KOPTContext_mt.__index:getReflowedWordBoxes(x, y, w, h) return self:getWordBoxes(x, y, w, h, 0) end
function KOPTContext_mt.__index:getNativeWordBoxes(x, y, w, h) return self:getWordBoxes(x, y, w, h, 1) end

function KOPTContext_mt.__index:reflowToNativePosTransform(xc, yc, wr, hr)
	local function wrectmap_reflow_distance(wrmap, x, y)
		local function wrectmap_reflow_inside(wrmap, x, y)
		    return k2pdfopt.wrectmap_inside(wrmap, ffi.new("int", x), ffi.new("int", y)) ~= 0
		end
		if wrectmap_reflow_inside(wrmap, x, y) then
			return 0
		else
			local x0, y0 = x, y
			local x1 = wrmap.coords[1].x + wrmap.coords[2].x / 2
			local y1 = wrmap.coords[1].y + wrmap.coords[2].y / 2
			return (x0 - x1)*(x0 - x1) + (y0 - y1)*(y0 - y1)
		end
	end
	
    local m = 0
    for i = 0, self.rectmaps.n - 1 do
    	if wrectmap_reflow_distance(self.rectmaps.wrectmap + m, xc, yc) > 
    		wrectmap_reflow_distance(self.rectmaps.wrectmap + i, xc, yc) then
    		m = i
    	end
    end
    local rectmap = self.rectmaps.wrectmap + m
    local x = rectmap.coords[0].x*self.dev_dpi*self.quality/rectmap.srcdpiw
	local y = rectmap.coords[0].y*self.dev_dpi*self.quality/rectmap.srcdpih
    local w = rectmap.coords[2].x*self.dev_dpi*self.quality/rectmap.srcdpiw
    local h = rectmap.coords[2].y*self.dev_dpi*self.quality/rectmap.srcdpih
    return (x+w*wr)/self.zoom+self.bbox.x0, (y+h*hr)/self.zoom+self.bbox.y0
end

function KOPTContext_mt.__index:nativeToReflowPosTransform(xc, yc)
	local function wrectmap_native_distance(wrmap, x0, y0)
		local function wrectmap_native_inside(wrmap, x0, y0)
		    return wrmap.coords[0].x <= x0 and wrmap.coords[0].y <= y0
					and wrmap.coords[0].x + wrmap.coords[2].x >= x0
					and wrmap.coords[0].y + wrmap.coords[2].y >= y0
		end
		if wrectmap_native_inside(wrmap, x0, y0) then
			return 0
		else
			local x = wrmap.coords[0].x*self.dev_dpi*self.quality/wrmap.srcdpiw
			local y = wrmap.coords[0].y*self.dev_dpi*self.quality/wrmap.srcdpih
		    local w = wrmap.coords[2].x*self.dev_dpi*self.quality/wrmap.srcdpiw
		    local h = wrmap.coords[2].y*self.dev_dpi*self.quality/wrmap.srcdpih
			local x1, y1 = x + w/2, y + h/2
			return (x0 - x1)*(x0 - x1) + (y0 - y1)*(y0 - y1)
		end
	end
	
	local m = 0
    local x0, y0 = (xc - self.bbox.x0) * self.zoom, (yc - self.bbox.y0) * self.zoom
    for i = 0, self.rectmaps.n - 1 do
    	if wrectmap_native_distance(self.rectmaps.wrectmap + m, x0, y0) > 
    		wrectmap_native_distance(self.rectmaps.wrectmap + i, x0, y0) then
    		m = i
    	end
    end
    local rectmap = self.rectmaps.wrectmap + m
    return rectmap.coords[1].x + rectmap.coords[2].x/2, rectmap.coords[1].y + rectmap.coords[2].y/2
end

function KOPTContext_mt.__index:getTOCRWord(x, y, w, h, datadir, lang, ocr_type, allow_spaces, std_proc)
	local word = ffi.new("char[256]")
	k2pdfopt.k2pdfopt_tocr_single_word(self.dst,
		ffi.new("int", x), ffi.new("int", y), ffi.new("int", w), ffi.new("int", h),
		word, 255, ffi.cast("char*", datadir), ffi.cast("char*", lang),
		ocr_type, allow_spaces, std_proc)
	return ffi.string(word)
end

function KOPTContext_mt.__index:getPageRegions()
	k2pdfopt.k2pdfopt_part_bmp(self)
	local w, h = self.page_width, self.page_height
	local regions = {}
	for i = 0, self.pageregions.n - 1 do
		local bmpregion = (self.pageregions.pageregion + i).bmpregion
		table.insert(regions, {
				x0 = bmpregion.c1/w, x1 = bmpregion.c2/w,
				y0 = bmpregion.r1/h, y1 = bmpregion.r2/h })
	end
	return regions
end

function KOPTContext_mt.__index:free()
	--[[ Don't worry about the src bitmap in context. It's freed as soon as it's
	     been used in either reflow or autocrop. But we should take care of dst
	     bitmap since the usage of dst bitmap is delayed most of the times.
	--]]
	local rnai = ffi.new('NUMA *[1]')
	local nnai = ffi.new('NUMA *[1]')
	local rboxa = ffi.new('BOXA *[1]')
	local nboxa = ffi.new('BOXA *[1]')
	rnai[0] = self.rnai
	nnai[0] = self.nnai
	rboxa[0] = self.rboxa
	nboxa[0] = self.nboxa
	
	leptonica.numaDestroy(rnai)
	leptonica.numaDestroy(nnai)
	leptonica.boxaDestroy(rboxa)
	leptonica.boxaDestroy(nboxa)
	k2pdfopt.bmp_free(self.dst)
	k2pdfopt.wrectmaps_free(self.rectmaps)
	k2pdfopt.pageregions_free(self.pageregions)
end

function KOPTContext_mt.__index:__gc() self:free() end
function KOPTContext_mt.__index:freeOCR() k2pdfopt.k2pdfopt_tocr_end() end

local kctype = ffi.metatype("KOPTContext", KOPTContext_mt)

function KOPTContext.new()
	local kc = kctype()
	-- integer values
	kc.trim = 1
	kc.wrap = 1
	kc.indent = 1
	kc.rotate = 0
	kc.columns = 2
	kc.offset_x = 0
	kc.offset_y = 0
	kc.dev_dpi = 167
	kc.dev_width = 600
	kc.dev_height = 800
	kc.page_width = 600
	kc.page_height = 800
	kc.straighten = 0
	kc.justification = -1
	kc.read_max_width = 3000
	kc.read_max_height = 4000
	kc.writing_direction = 0
	-- number values
	kc.zoom = 1.0
	kc.margin = 0.06
	kc.quality = 1.0
	kc.contrast = 1.0
	kc.defect_size = 1.0
	kc.line_spacing = 1.2
	kc.word_spacing = -1
	kc.shrink_factor = 0.9
	-- states
	kc.precache = 0
	kc.debug = 0
	kc.cjkchar = 0
	-- struct
	kc.bbox = ffi.new("struct BBox", {0.0, 0.0, 0.0, 0.0})
	-- pointers
	kc.rboxa = nil
	kc.rnai = nil
	kc.nboxa = nil
	kc.nnai = nil
	kc.language = nil
	
	k2pdfopt.bmp_init(kc.src)
	k2pdfopt.bmp_init(kc.dst)
	k2pdfopt.wrectmaps_init(kc.rectmaps)
	k2pdfopt.pageregions_init(kc.pageregions)
	
	return kc
end

return KOPTContext
