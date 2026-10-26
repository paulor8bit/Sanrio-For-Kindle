local InputContainer=require("ui/widget/container/inputcontainer")
local UIManager=require("ui/uimanager")
local Device=require("device")
local Geom=require("ui/geometry")
local GestureRange=require("ui/gesturerange")
local TextWidget=require("ui/widget/textwidget")
local ImageWidget=require("ui/widget/imagewidget")
local RenderImage=require("ui/renderimage")
local Font=require("ui/font")
local BB=require("ffi/blitbuffer")
local View=InputContainer:extend{covers_fullscreen=true,modal=true}
local BLACK,WHITE,GRAY,LIGHT=BB.COLOR_BLACK,BB.COLOR_WHITE,BB.Color8(170),BB.Color8(238)
local function round(n) return math.floor(n+0.5) end
local function minutes(n) return math.max(0,math.ceil(n/60)) end
local function savedDate(at)
 local ok,date=pcall(os.date,"%d/%m/%Y, %H:%M",at)
 return ok and date or "Data indisponível"
end
local function readyLabel(label,remaining)
 if remaining<=0 then return label end
 if remaining>=3600 then return label.." "..math.ceil(remaining/3600).."h" end
 return label.." "..minutes(remaining).."m"
end
function View:init()
 self.art=dofile(self.path.."/art.lua");self.frames=dofile(self.path.."/assets/frames.lua")
 self.poses=dofile(self.path.."/assets/poses.lua")
 self.sprites=dofile(self.path.."/assets/sprites.lua")
 self.screen="home";self.frame=1;self.buttons={};self.images={};self.action_count=0;self.starter_index=1
 self.message=self.engine.act(self.state,"check",nil,os.time())
 self.key_events.Back={{"Back"}};self.key_events.Close={{"Esc"}};self:geometry()
 -- The only scheduled callback is a bounded animation following an action.
 self.tick=function()
  if self.closed or self.suspended or Device.screen_saver_mode then self:stopAnimation();return end
  if not self.animating then return end
  self.step=self.step+1;self.frame=self.sequence[self.step]
  if not self.frame then
   self.frame=1;self.animating=false;self.effect=nil;self.previous_species=nil;self:freeImages()
  else UIManager:scheduleIn(self.interval,self.tick) end
  UIManager:setDirty(self,"ui",self:stageRegion())
 end
end
function View:geometry()
 local w,h=Device.screen:getWidth(),Device.screen:getHeight()
 self.dimen=Geom:new{x=0,y=0,w=w,h=h};self.scale=math.min(w/600,h/800)
 self.ox=round((w-600*self.scale)/2);self.oy=round((h-800*self.scale)/2)
 -- Font:getFace scales again in KOReader. Our layout already uses screen pixels.
 self.font_scale=Device.screen.scaleBySize and 600/Device.screen:scaleBySize(600)
 self.ges_events.Tap={GestureRange:new{ges="tap",range=self.dimen}}
 self.ges_events.Swipe={GestureRange:new{ges="swipe",range=self.dimen}}
end
function View:region(x,y,w,h)
 return Geom:new{x=self.ox+round(x*self.scale),y=self.oy+round(y*self.scale),w=round(w*self.scale),h=round(h*self.scale)}
end
function View:stageRegion()
 if self.screen=="entry" then return self:region(120,184,360,280) end
 return self:region(32,180,536,240)
end
function View:animationSpecies() return self.screen=="entry" and self.detail_id or self.state.species end
function View:rect(bb,x,y,w,h,color)
 local r=self:region(x,y,w,h);bb:paintRect(r.x,r.y,r.w,r.h,color or BLACK)
end
function View:outline(bb,x,y,w,h,color)
 self:rect(bb,x,y,w,1,color);self:rect(bb,x,y+h-1,w,1,color)
 self:rect(bb,x,y,1,h,color);self:rect(bb,x+w-1,y,1,h,color)
end
function View:fontFace(size,bold)
 local pixels=math.max(9,round(size*self.scale))
 -- KOReader rounds up; aim halfway inside the target pixel to avoid rounding twice.
 local size_arg=self.font_scale and (pixels-0.5)*self.font_scale or pixels
 return Font:getFace(bold and "tfont" or "cfont",size_arg)
end
function View:text(bb,text,x,y,size,width,bold,center,height)
 if self.engine.companion.option(self.state,"large_text") and size<20 then size=math.min(21,size+2) end
 if self.engine.companion.option(self.state,"high_contrast") then bold=true end
 local t=TextWidget:new{text=tostring(text),face=self:fontFace(size,bold),bold=bold,max_width=round((width or 536)*self.scale),padding=0}
 local r=self:region(x,y,0,0)
 if center then r.x=r.x+round(((width or 536)*self.scale-t:getSize().w)/2) end
 if height then r.y=r.y+round((round(height*self.scale)-t:getSize().h)/2) end
 t:paintTo(bb,r.x,r.y);t:free()
end
function View:wrapped(bb,text,y,size)
 local measure=size or 17
 if self.engine.companion.option(self.state,"large_text") and measure<20 then measure=math.min(21,measure+2) end
 local bold=self.engine.companion.option(self.state,"high_contrast")
 local face=self:fontFace(measure,bold)
 local line,rows="",{}
 for word in text:gmatch("%S+") do
  local trial=line=="" and word or line.." "..word
  local t=TextWidget:new{text=trial,face=face,bold=bold,padding=0}
  local too_wide=t:getSize().w>round(504*self.scale);t:free()
  if too_wide and line~="" then rows[#rows+1]=line;line=word else line=trial end
 end
 rows[#rows+1]=line
 for i=1,math.min(2,#rows) do self:text(bb,rows[i],46,y+(i-1)*22,size or 17,508,false,true) end
end
function View:button(bb,label,x,y,w,h,action,arg,icon,disabled,selected)
 if disabled then label="- "..label end
 if selected then self:rect(bb,x,y,w,h,LIGHT) end
 self:outline(bb,x,y,w,h,disabled and GRAY or BLACK)
 if icon then
  self.art.icon(self,bb,icon,x+12,y+round((h-20)/2),2,disabled and GRAY or BLACK)
  self:text(bb,label,x+40,y,18,w-44,false,true,h)
 else self:text(bb,label,x+6,y,18,w-12,selected,true,h) end
 self.buttons[#self.buttons+1]={x=x,y=y,w=w,h=h,action=action,arg=arg,disabled=disabled}
end
function View:progress(bb,x,y,w,value,total)
 self:outline(bb,x,y,w,12,GRAY)
 self:rect(bb,x+2,y+2,math.floor((w-4)*math.max(0,math.min(1,value/total))),8)
end
function View:sprite(bb,id,x,y,size,frame,pose)
 local pose_list=self.poses[id]
 if pose and (not pose_list or not pose_list[pose]) then pose=pose_list and "idle" or nil end
 frame=math.min(frame or 1,pose and pose_list[pose] or self.frames[id] or 1)
 local key=id.."-"..(pose or "normal").."-"..frame.."-"..round(size*self.scale);local img=self.images[key]
 if not img then
  local file=id.."-"..(pose and pose.."-" or "")..frame..".png"
  local data=self.sprites.read(self.path.."/assets",file)
  local raw=RenderImage:renderImageData(data,#data,false)
  assert(raw,"Não foi possível decodificar o sprite do SanrioKindle: "..file)
  local pixels=round(size*self.scale);local scaled=raw
  if raw:getWidth()~=pixels or raw:getHeight()~=pixels then scaled=raw:scale(pixels,pixels);raw:free() end
  img=ImageWidget:new{image=scaled,image_disposable=true,alpha=true,width=pixels,height=pixels,scale_for_dpi=false}
  self.images[key]=img
 end
 local r=self:region(x,y,0,0);img:paintTo(bb,r.x,r.y)
end
function View:freeImages()
 for _,img in pairs(self.images) do img:free() end;self.images={}
 if self.stage_background then self.stage_background:free();self.stage_background=nil end
 self.stage_cached=false
end
function View:stopAnimation()
 UIManager:unschedule(self.tick);self.animating=false;self.frame=1;self.effect=nil;self.previous_species=nil
end
function View:poseFor(effect)
 local id=self:animationSpecies()
 if not self.poses[id] then return nil end
 if self.screen=="entry" then return self.preview_pose or "idle" end
 if effect=="rest" or effect=="ambient_sleep" then return self.state.resting and "sleep" or "idle" end
 if effect=="feed" then return self.poses[self:animationSpecies()].eat and "eat" or "idle" end
 if effect=="train" then return "attack" end
 if effect=="play" then return "walk" end
 return self.state.resting and "sleep" or "idle"
end
function View:animate(effect,previous)
 self:stopAnimation()
 if not effect or self.state.animation=="off" or self.suspended or Device.screen_saver_mode then return end
 if self.screen=="home" and self.engine.tripLeft(self.state,os.time())>0 and effect~="explore" then return end
 self.effect=effect;self.previous_species=previous;self.animating=true;self.step=1;self.frame=1
 local pose=self:poseFor(effect)
 local count=pose and self.poses[self:animationSpecies()][pose] or self.frames[self:animationSpecies()] or 1
 self.sequence={}
 if self.state.animation=="eco" then self.sequence={1,math.min(count,math.floor(count/2)+1)};self.interval=0.8
 else for i=1,count do self.sequence[#self.sequence+1]=i end;self.interval=0.45 end
 UIManager:scheduleIn(self.interval,self.tick)
end
function View:go(screen)
 self:stopAnimation();self:freeImages();self.screen=screen;self.page=1;self.hatched=nil;UIManager:setDirty(self,"ui")
 local now=os.time()
 if now>self.state.last and not (self.owner.backups and self.owner.backups.blocked) then
  self.engine.advance(self.state,now);self.owner:save()
 end
 if screen=="nickname" then self.nickname_text=self.state.nicknames and self.state.nicknames[tostring(self.state.species)] or "";self.uppercase=true end
 if screen=="backups" then self:loadBackups() end
end
function View:act(action,arg)
 if self.owner.backups and self.owner.backups.blocked then return end
 local previous=self.state.species
 local hatching=action=="hatch" and self.state.egg and self.state.egg.id
 self.message,self.next_effect=self.engine.act(self.state,action,arg,os.time())
 self.owner:save();self:freeImages();self.screen="home";self.entry_from=nil
 if hatching and not self.state.egg then
  self.screen="entry";self.detail_id=hatching;self.preview_pose="idle";self.hatched=hatching;self.next_effect="hello"
 end
 self:animate(self.next_effect,self.next_effect=="evolve" and previous or nil)
 self.action_count=self.action_count+1;UIManager:setDirty(self,self.action_count%12==0 and "flashui" or "ui")
end
function View:paintTo(bb,x,y)
 bb:paintRect(0,0,self.dimen.w,self.dimen.h,WHITE);self.buttons={}
 self.art.text(self,bb,"SANRIOKINDLE",32,28,2);self.art.icon(self,bb,"berry",373,24,2)
 self:text(bb,self.state.berries,406,29,18,64);self:button(bb,"Sair",492,20,76,40,"exit")
 self:rect(bb,32,75,536,1)
 if self.state.species==0 and self.screen~="allcompanions" and self.screen~="entry" then self:paintWelcome(bb)
 elseif self.screen=="home" then self:paintHome(bb)
 elseif self.screen=="explore" then self:paintExplore(bb)
 elseif self.screen=="journal" or self.screen=="companions" or self.screen=="allcompanions" then self:paintJournal(bb)
 elseif self.screen=="entry" then self:paintEntry(bb)
 elseif self.screen=="history" then self:paintHistory(bb)
 elseif self.screen=="profile" then self:paintProfile(bb)
 elseif self.screen=="badges" then self:paintBadges(bb)
 elseif self.screen=="play" then self:paintPlay(bb)
 elseif self.screen=="train" then self:paintTrain(bb)
 elseif self.screen=="help" then self:paintHelp(bb)
 elseif self.screen=="reading" then self:paintReading(bb)
 elseif self.screen=="egg" then self:paintEgg(bb)
 elseif self.screen=="backgrounds" then self:paintBackgrounds(bb)
 elseif self.screen=="recap" then self:paintRecap(bb)
 elseif self.screen=="weekly" then self:paintWeekly(bb)
 elseif self.screen=="decorations" then self:paintDecorations(bb)
 elseif self.screen=="nickname" then self:paintNickname(bb)
 elseif self.screen=="backups" then self:paintBackups(bb)
 elseif self.screen=="restore" then self:paintRestore(bb)
 elseif self.screen=="preferences" then self:paintPreferences(bb)
 elseif self.screen=="sleeppreview" then self:paintSleep(bb,true)
 elseif self.screen=="filters" then self:paintFilters(bb)
 elseif self.screen=="snacks" then self:paintSnacks(bb)
 elseif self.screen=="memories" then self:paintMemories(bb)
 elseif self.screen=="bookconfirm" then self:paintBookConfirm(bb)
 elseif self.screen=="readinghistory" then self:paintReadingHistory(bb)
 elseif self.screen=="trailstory" then self:paintTrailStory(bb)
 elseif self.screen=="textentry" then self:paintTextEntry(bb)
 else self:paintMore(bb) end
 if self.owner.save_error and not (self.owner.backups and self.owner.backups.blocked) then
  self:text(bb,"Não salvo. Verifique o espaço livre e tente de novo.",32,774,16,536,true,true)
 end
end
function View:paintWelcome(bb)
 local id=self.engine.starters[self.starter_index]
 self:text(bb,"Escolha seu parceiro",32,105,29,536,true,true)
 self:text(bb,self.engine.name(id),32,166,25,536,true,true);self:sprite(bb,id,176,218,248,1)
 self:text(bb,self.starter_index.." / "..#self.engine.starters,32,488,18,536,false,true)
 self:wrapped(bb,"Alimente, brinque, explore e cresçam juntos. Escolha um amigo para a aventura.",530,19)
 self:button(bb,"Anterior",60,602,232,48,"starter",-1)
 self:button(bb,"Próximo",308,602,232,48,"starter",1)
 self:button(bb,"Começar com "..self.engine.name(id),60,658,480,52,"choose",id,"heart")
 self:button(bb,"Escolher entre os 4 amigos",60,720,480,44,"nav","allcompanions")
end
function View:landscape(bb,background)
 local hour=tonumber(os.date("%H"));local night=hour<7 or hour>=19
 self.art.scene(self,bb,background or self.state.background or 1,night,WHITE,GRAY,LIGHT)
 self.art.decorate(self,bb,self.state.decor,WHITE,GRAY,LIGHT)
 if self.screen=="home" and self.state.dirt>=15 then self.art.icon(self,bb,"poop",122,381,2,BB.Color8(85)) end
end
function View:paintHome(bb)
 local s=self.state;local now=os.time()
 self:text(bb,self.engine.displayName(s),32,94,27,395,true);self:text(bb,"Nv. "..self.engine.level(s),438,94,25,130,true,true)
 self:text(bb,self.engine.mood(s,now),32,124,17,536,false,true)
 self:paintHomeStage(bb)
 local left=self.engine.tripLeft(s,now)
 local recap=self.owner.recap
 if recap and not self.recap_dismissed then
  self:button(bb,math.floor(recap.seconds/60).." min lidos / +"..recap.berries.." frutas / +"..recap.xp.." XP",32,431,462,42,"nav","recap")
  self:button(bb,"X",506,431,62,42,"dismissrecap")
 else self:wrapped(bb,self.owner.reading_busy and "Conferindo tempo de leitura..." or self.message,433) end
 local stats={{"Comida",s.food},{"Alegria",s.joy},{"Energia",s.energy},{"Higiene",100-s.dirt}}
 for i,v in ipairs(stats) do
  local x=32+((i-1)%2)*276;local y=486+math.floor((i-1)/2)*36
  self:text(bb,v[1].." "..math.floor(v[2]),x,y,16,140);self:outline(bb,x+146,y+3,114,12)
  self:rect(bb,x+148,y+5,math.floor(110*v[2]/100),8)
 end
 self:text(bb,self.engine.ready(s) and "Já pode evoluir!" or "Vínculo "..math.floor(s.bond).." / 100   |   "..s.xp.." XP",32,559,17,350)
 self:button(bb,"Perfil",431,547,137,36,"nav","profile")
 local buttons={{"Alimentar","feed",nil,"berry"},{readyLabel("Brincar",s.played+1800-now),"startplay",nil,"ball"},{readyLabel("Praticar",s.trained+3600-now),"nav","train","ball"},
  {s.resting and "Acordar" or "Descansar","rest",nil,"moon"},{s.trip>0 and left==0 and "Recolher!" or "Explorar","nav","explore","boot"},{"Diário","nav","journal","book"},
  {"Limpar","clean",nil,"clean"},{readyLabel("Cesta",s.gift+86400-now),"gift",nil,"berry"},{"Mais","nav","more","settings"}}
 for i,b in ipairs(buttons) do self:button(bb,b[1],32+(i-1)%3*182,596+math.floor((i-1)/3)*57,172,48,b[2],b[3],b[4]) end
 if s.egg then self.buttons[#self.buttons+1]={x=416,y=344,w=60,h=67,action="nav",arg="egg"} end
 self.buttons[#self.buttons+1]={x=168,y=211,w=264,h=204,action=s.trip>0 and "nav" or "hello",arg=s.trip>0 and "explore" or nil}
end
function View:paintHomeStage(bb)
 local s=self.state;local now=os.time();local left=self.engine.tripLeft(s,now)
 local r=self:stageRegion()
 if self.stage_cached and host_stage_restore then host_stage_restore()
 elseif self.stage_background and bb.blitFrom then bb:blitFrom(self.stage_background,r.x,r.y,r.x,r.y,r.w,r.h)
 else
  self:rect(bb,32,180,536,240,WHITE);self:landscape(bb)
  if host_stage_save then host_stage_save(r.x,r.y,r.w,r.h);self.stage_cached=true
  elseif bb.copy then self.stage_background=bb:copy() end
 end
 if s.trip>0 and left>0 and not self.animating then
  self:rect(bb,157,236,286,169,WHITE)
  self.art.icon(self,bb,"boot",270,247,6);self:text(bb,self.engine.routes[s.trip].name,169,310,20,263,true,true)
  self:text(bb,minutes(left)..(s.trail~=nil and " min de leitura restantes" or " min até voltar"),169,343,17,263,false,true)
  self:progress(bb,181,381,238,self.engine.routes[s.trip].seconds-left,self.engine.routes[s.trip].seconds)
 else
  local size=192;local id=s.species
  for i,member in ipairs(self.engine.evolutionLine(id)) do if member==id then size=176+i*16 end end
  if self.effect=="evolve" and self.previous_species and self.step<=2 then id=self.previous_species end
  local dy=(self.animating and self.effect=="play" and self.frame%2==0) and -6 or 0
  self:rect(bb,253,401,94,3,GRAY);self:rect(bb,265,398,70,3,GRAY)
  local pose=self.animating and self:poseFor(self.effect) or self:poseFor(nil)
  local px=(600-size)/2
  if s.decor and not self.animating then
   if s.resting and s.decor[1] then px=218-size/2
   elseif not s.resting and s.decor[2] and tonumber(os.date("%H"))%3==0 then px=458-size/2;pose="idle"
   elseif not s.resting and s.decor[4] and tonumber(os.date("%H"))%3==1 then px=150-size/2;pose="idle" end
  end
  self:sprite(bb,id,px,414-size+dy,size,self.frame,pose)
  if self.animating and self.effect~="ambient" and self.effect~="ambient_sleep" then self:paintEffect(bb) end
 end
 if s.egg then
  self.art.gift(self,bb,422,353,3,1-self.engine.eggLeft(s)/self.engine.egg_seconds,WHITE)

 end
end
function View:paintStage(bb)
 if self.screen=="home" then self:paintHomeStage(bb)
 elseif self.screen=="entry" then self:rect(bb,120,184,360,280,WHITE);self:sprite(bb,self.detail_id,174,196,252,self.frame,self.preview_pose or "idle")
 else self:paintTo(bb,0,0) end
end
function View:paintEffect(bb)
 local up=self.frame%2==0 and -7 or 0;local e=self.effect
 if e=="feed" then self.art.icon(self,bb,"berry",160,279+up,3)
 elseif e=="play" then self.art.icon(self,bb,"ball",409,277+up,3)
 elseif e=="train" then self.art.icon(self,bb,"ball",410,275+up,3)
 elseif e=="clean" or e=="evolve" then self.art.icon(self,bb,"clean",148,248+up,3);self.art.icon(self,bb,"clean",414,284-up,3)
 elseif e=="rest" then return
 else self.art.icon(self,bb,"heart",419,253+up,3) end
end
function View:backButton(bb) self:button(bb,"Voltar ao parceiro",32,717,536,44,"nav","home") end
function View:title(bb,title,subtitle)
 self:text(bb,title,32,101,29,536,true);if subtitle then self:text(bb,subtitle,32,145,17,536) end
end
function View:paintExplore(bb)
 local s=self.state
 self:title(bb,"Expedições","Escolha uma trilha e descubra novos amigos.")
 if s.trip>0 then
  local left=self.engine.tripLeft(s,os.time());local r=self.engine.routes[s.trip]
  self:text(bb,r.name,32,196,27,536,true,true)
  self:text(bb,left==0 and "Suas descobertas estão prontas." or minutes(left)..(s.trail~=nil and " minutos de leitura restantes" or " minutos até voltar"),32,241,20,536,false,true)
  self:progress(bb,62,283,476,r.seconds-left,r.seconds)
  for i,item in ipairs(s.finds~=nil and self.engine.discoveries or {}) do
   local y=327+(i-1)*70;local found=s.finds and s.finds>=i
   self.art.icon(self,bb,found and "badge" or "boot",46,y+5,3,found and BLACK or GRAY)
   self:text(bb,item.name..(found and " / encontrado" or " / "..i*25 .."%"),94,y,20,460,true)
   self:text(bb,item.detail,94,y+30,17,460)
  end
  if s.finds==nil then self:wrapped(bb,"Seu parceiro já está a caminho. As descobertas começam na próxima expedição.",387,19) end
  self:wrapped(bb,s.trail~=nil and s.reading and not s.reading.enabled and "Recompensas de leitura pausadas. Ative em Leitura."
   or s.trail~=nil and "Continue lendo. Volte para ver as descobertas do seu parceiro." or "Seu parceiro explora com o jogo fechado.",549,17)
  local story=left==0 and s.companion and s.companion.journey
  self:button(bb,story and "Ouvir sobre a trilha" or left==0 and "Recolher descobertas" or "Ver expedição",62,595,476,55,story and "nav" or "collect",story and "trailstory" or nil,"boot")
  self:text(bb,"Ao concluir: +"..r.berries.." frutas, +"..r.xp.." XP e um amigo",32,672,17,536,false,true)
 else
  local timed=self.trip_mode~="reading"
  self:button(bb,"Com a leitura",32,185,262,46,"tripmode","reading",nil,false,not timed)
  self:button(bb,"Por tempo",306,185,262,46,"tripmode","timed",nil,false,timed)
  for i,r in ipairs(self.engine.routes) do
   local y=253+(i-1)*139
   self:button(bb,r.name.." / "..r.seconds/60 .." min",32,y,536,54,timed and "trip" or "readingtrip",i,"boot")
   self:text(bb,r.energy.." de energia   +"..r.berries.." frutas   +"..r.xp.." XP",43,y+65,18,513)
   self:text(bb,i==1 and "Encontre Hello Kitty e My Melody no jardim." or i==2 and "Cinnamoroll adora passear entre as nuvens." or "Kuromi e My Melody passeiam sob o luar.",43,y+94,16,513)
  end
  self:text(bb,timed and "As expedições terminam com o passar do tempo." or "Só o tempo de leitura registrado avança a trilha.",32,666,17,536,false,true)
 end
 self:backButton(bb)
end
function View:paintEgg(bb)
 local s=self.state;local left=self.engine.eggLeft(s);local ready=s.egg and left==0
 self:title(bb,"Mais um capítulo",s.egg and "Um presente espera por você." or "Um amigo surpresa para suas pausas de leitura.")
 self.art.gift(self,bb,244,218,7,s.egg and 1-left/self.engine.egg_seconds or 0,WHITE)
 self:text(bb,ready and "Seu presente está pronto!" or s.egg and minutes(left).." minutos de leitura para abrir" or "Abre após 120 minutos de leitura",32,378,23,536,true,true)
 self:progress(bb,62,427,476,s.egg and self.engine.egg_seconds-left or 0,self.engine.egg_seconds)
 self:wrapped(bb,s.egg and "Continue lendo e volte para abrir seu presente." or "Pegue um presente por 3 frutas. Ele traz uma visita surpresa, priorizando novos amigos.",476,18)
 if s.egg then
  self:button(bb,ready and "Abrir presente" or "Continuar lendo",62,572,476,56,"hatch",nil,nil,not ready)
 else self:button(bb,"Pegar presente / 3 frutas",62,572,476,56,"egg") end
 self:text(bb,s.reading and not s.reading.enabled and "Recompensas de leitura pausadas. Ative em Leitura."
  or "Amigos vão para o diário. Seu parceiro fica.",32,661,17,536,false,true)
 self:backButton(bb)
end
function View:paintRecap(bb)
 local r=self.owner.recap
 self:title(bb,"Boas-vindas de volta",r and "Desde sua última visita" or "Sua próxima leitura aparecerá aqui.")
 if r then
  self:text(bb,r.seconds<60 and "Menos de um minuto de leitura" or math.floor(r.seconds/60).." min lidos",32,205,30,536,true,true)
  self:text(bb,"+"..r.berries.." frutas    +"..r.xp.." XP",32,259,24,536,false,true)
  if r.route>0 then
   local total=self.engine.routes[r.route].seconds
   self:text(bb,self.engine.routes[r.route].name,46,336,21,508,true)
   self:text(bb,math.floor(100*r.trip_before/total).."% to "..math.floor(100*r.trip_after/total).."% of the trail",46,370,18,508)
   self:progress(bb,46,406,508,r.trip_after,total)
  else self:text(bb,"Escolha uma trilha em Explorar para o próximo capítulo.",46,370,18,508) end
  if r.egg then
   local percent=math.floor(100*r.egg_after/self.engine.egg_seconds)
   self:text(bb,percent==100 and "Seu presente está pronto para abrir!" or "Seu presente está "..percent.."% preparado",46,464,21,508,true)
   self:progress(bb,46,508,508,r.egg_after,self.engine.egg_seconds)
  else self:text(bb,"Prepare presentes lendo. Pegue um por 3 frutas.",46,479,18,508) end
  if r.events then self:wrapped(bb,"Encontrou: "..table.concat(r.events,", "),550,17) end
  self:wrapped(bb,r.weekly and "Meta semanal cumprida! O bônus está incluído acima." or "Continue lendo. Sua próxima visita trará mais progresso.",610,18)
 end
 self:backButton(bb)
end
function View:paintWeekly(bb)
 local w=self.state.week
 self:title(bb,"Uma pequena meta de leitura","Recomeça toda segunda, sem sequência obrigatória.")
 self:text(bb,"Quanto você gostaria de ler?",32,203,22,536,true,true)
 for i,target in ipairs(self.engine.weekly_targets) do
  self:button(bb,target/60 .." min",32+(i-1)*182,257,172,54,"goal",target,nil,false,w and w.target==target)
 end
 if w then
  self:text(bb,math.floor(w.seconds/60).." / "..w.target/60 .." min nesta semana",32,367,27,536,true,true)
  self:progress(bb,62,423,476,w.seconds,w.target)
  self:wrapped(bb,w.claimed and "Meta cumprida. Seu bônus já foi recolhido." or "Cumpra a meta por mais 5 frutas e 10 XP.",478,19)
 else self:wrapped(bb,"Escolha uma meta. Cumpra por mais 5 frutas e 10 XP.",384,20) end
 self:wrapped(bb,"Os minutos contam na semana da coleta. Você pode mudar a meta sem perder o progresso.",590,18)
 self:backButton(bb)
end
function View:paintBackgrounds(bb)
 self:title(bb,"Sinta-se em casa")
 self:landscape(bb);self:sprite(bb,self.state.species,204,222,192,1,self.state.resting and "sleep" or "idle")
 for i,name in ipairs(self.engine.backgrounds) do
  self:button(bb,name,32+(i-1)%2*274,445+math.floor((i-1)/2)*78,262,56,"background",i,nil,false,(self.state.background or 1)==i)
 end
 self:text(bb,"Toque em um cenário para usar como fundo.",32,675,17,536,false,true)
 self:backButton(bb)
end
function View:paintDecorations(bb)
 self:title(bb,"Algo para seu cantinho")
 self:landscape(bb);self:sprite(bb,self.state.species,204,222,192,1,self.state.resting and "sleep" or "idle")
 for id,item in ipairs(self.engine.decorations) do
  local placed=self.state.decor and self.state.decor[id]
  local label=placed~=nil and ((placed and "Guardar: " or "Colocar: ")..item.name:lower()) or item.name.." / "..item.cost.." frutas"
  self:button(bb,label,32+(id-1)%2*274,445+math.floor((id-1)/2)*78,262,56,"decorate",id,nil,false,placed)
 end
 self:wrapped(bb,self.decor_message or "Compre uma vez e use em qualquer cenário. Guarde quando quiser.",625,18)
 self:backButton(bb)
end
function View:paintJournal(bb)
 local choosing=self.screen=="companions" or self.screen=="allcompanions"
 local ids={}
 if choosing then
  local starters={};for _,id in ipairs(self.engine.starters) do starters[id]=true end
  for id=1,#self.engine.species do
   if self.screen=="allcompanions" or starters[id] or self.state.seen[tostring(id)] then ids[#ids+1]=id end
  end
 else ids=self.engine.companion.journal(self.state,self.engine,self.journal_query,self.journal_filter or "met") end
 self.journal_count=#ids
 local pages=math.max(1,math.ceil(#ids/6));self.page=math.min(self.page or 1,pages)
 if choosing then
  self:title(bb,self.screen=="allcompanions" and "Todos os 4 amigos" or "Trocar parceiro",
   self.screen=="allcompanions" and "Todos os personagens estão disponíveis para escolher." or "Iniciais e amigos que você conheceu.")
  self:wrapped(bb,"Toque em um amigo para ver detalhes e escolher.",190,18)
 else
  self:title(bb,"Diário de amigos",self.engine.friendsCount(self.state).." / 4 amigos   |   "..#ids.." na lista")
  self:button(bb,self.journal_query and self.journal_query~="" and self.journal_query or "Buscar",32,184,172,42,"journalSearch")
  self:button(bb,"Filtrar",214,184,172,42,"nav","filters")
  self:button(bb,"Meu parceiro",396,184,172,42,"entry",self.state.species)
 end
 for pos=(self.page-1)*6+1,math.min(self.page*6,#ids) do
  local i=pos-(self.page-1)*6-1;local x=32+(i%3)*182;local y=241+math.floor(i/3)*164
  self:sprite(bb,ids[pos],x+28,y,116,1);self:text(bb,self.engine.displayName(self.state,ids[pos]),x,y+124,17,172,false,true)
  self.buttons[#self.buttons+1]={x=x,y=y,w=172,h=154,action="entry",arg=ids[pos]}
 end
 self:button(bb,"Anterior",32,597,170,43,"page",-1,nil,self.page==1)
 self:text(bb,self.page.." / "..pages,217,609,20,166,false,true)
 self:button(bb,"Próximo",398,597,170,43,"page",1,nil,self.page==pages)
 if choosing then
  if self.screen=="companions" then
   self:button(bb,"Escolher entre os 4 amigos",32,652,536,44,"nav","allcompanions")
  else self:wrapped(bb,"Cada amigo mantém seu XP, vínculo e apelido.",662,18) end
  local back=self.state.species==0 and "home" or self.screen=="allcompanions" and "companions" or "profile"
  local label=back=="home" and "Voltar aos iniciais" or back=="companions" and "Voltar aos parceiros" or "Voltar ao perfil"
  self:button(bb,label,32,717,536,44,"nav",back)
 else
  self:button(bb,"Atividades",32,659,262,43,"nav","history","book")
  self:button(bb,"Insígnias",306,659,262,43,"nav","badges","badge");self:backButton(bb)
 end
end
function View:paintEntry(bb)
 local id=self.detail_id;local name=self.engine.name(id)
 self:title(bb,self.hatched==id and "Acabou de nascer!" or string.format("#%03d  %s",id,name),
  (self.hatched==id and name.."   /   " or "")..self.engine.labels.types(self.engine.species[id].types))
 self:sprite(bb,id,174,196,252,self.frame,self.preview_pose or "idle")
 local poses={{"Parado","idle"},{"Dormindo","sleep"},{"Andando","walk"},{"Atacando","attack"},{"Comendo","eat"}}
 for i,p in ipairs(poses) do
  local available=self.poses[id] and self.poses[id][p[2]]
  self:button(bb,p[1],32+(i-1)*109,476,100,46,"preview",p[2],nil,not available,self.preview_pose==p[2])
 end
 local p=id==self.state.species and self.state or (self.state.partners and self.state.partners[tostring(id)]) or {xp=0,bond=0}
 self:text(bb,p.xp.." XP   /   Vínculo "..math.floor(p.bond).."   /   Toque em uma pose",32,546,17,536,false,true)
 local label=id==self.state.species and "Seu parceiro atual" or self.state.trip>0 and "Recolha a expedição antes de trocar"
  or self.state.resting and "Acorde antes de trocar" or "Escolher "..name
 self:button(bb,label,32,594,536,52,self.state.species==0 and "choose" or "partner",id,"heart",id==self.state.species or self.state.trip>0 or self.state.resting)
 local C=self.engine.companion;local trait,berry=C.profile(self.state,id,self.engine)
 local c=self.state.companion;local known=c and c.tastes[tostring(id)]
 self:text(bb,trait..(known and " / Gosta de "..berry or " / Experimente outras frutas"),32,658,17,344)
 self:button(bb,c and c.favourites[tostring(id)] and "Desfavoritar" or "Favoritar",398,652,170,42,"favourite",id,nil,not self.state.seen[tostring(id)])
 local back=self.entry_from or "journal"
 self:button(bb,back=="journal" and "Voltar ao diário" or back=="allcompanions" and "Voltar aos 4 amigos" or "Voltar aos parceiros",32,717,536,44,"nav",back)
end
function View:paintHistory(bb)
 local entries=self.state.log
 local pages=math.max(1,math.ceil(#entries/6));self.page=math.min(self.page or 1,pages)
 self:title(bb,"Atividades",#entries.." momentos recentes")
 for pos=(self.page-1)*6+1,math.min(self.page*6,#entries) do
  local i=pos-(self.page-1)*6-1;local y=191+i*66
  local stamp,entry=entries[pos]:match("^(.-) | (.*)$")
  if stamp then self:text(bb,stamp,44,y,14,510);self:text(bb,entry,44,y+23,18,510)
  else self:text(bb,entries[pos],44,y+12,18,510) end
  self:rect(bb,44,y+56,512,1,LIGHT)
 end
 self:button(bb,"Anterior",32,597,170,43,"page",-1,nil,self.page==1)
 self:text(bb,self.page.." / "..pages,217,609,20,166,false,true)
 self:button(bb,"Próximo",398,597,170,43,"page",1,nil,self.page==pages)
 self:button(bb,"Diário de amigos",32,659,536,43,"nav","journal","book")
 self:backButton(bb)
end
function View:paintProfile(bb)
 local s=self.state;local lv=self.engine.level(s)
 self:title(bb,"Amigo de leitura",self.engine.displayName(s).."   /   Nv. "..lv.."   /   Vínculo "..math.floor(s.bond).." / 100")
 self:button(bb,"Trocar amigo",182,97,239,40,"nav","companions")
 self:button(bb,"Apelido",431,97,137,40,"nav","nickname")
 self:sprite(bb,s.species,204,183,192,1,"idle")
 self:text(bb,self.engine.name(s.species),32,390,25,536,true,true)
 self:text(bb,self.engine.species[s.species].types,32,428,20,536,false,true)
 self:wrapped(bb,self.engine.name(s.species).." adora sua companhia. Continuem lendo, brincando e descobrindo amigos.",480,19)
 self:text(bb,"Cada 20 XP dá um nível de amizade.",32,559,19,536,false,true)
 self:progress(bb,62,606,476,s.xp%20,20)
 self:text(bb,"Juntos há "..math.max(0,math.floor((os.time()-s.started)/86400)).." dias   /   "..s.trips.." passeios",32,681,18,536,false,true)
 self:backButton(bb)
end
function View:paintNickname(bb)
 self:title(bb,"Como vamos chamar você?","Até 12 caracteres para seu amigo.")
 self:outline(bb,32,198,536,58)
 self:text(bb,self.nickname_text~="" and self.nickname_text or self.engine.name(self.state.species),48,211,25,504,true,true)
 self:text(bb,#(self.engine.companion.text.chars(self.nickname_text) or {}).." / 12",32,271,16,300,false,true)
 self:button(bb,"Teclado",398,263,170,38,"unicodekeyboard")
 self:paintKeys(bb,"nickkey")
 self:button(bb,self.uppercase and "abc" or "ABC",32,553,172,46,"nickcase")
 self:button(bb,"Espaço",214,553,172,46,"nickkey"," ")
 self:button(bb,"Apagar",396,553,172,46,"nickdelete")
 self:button(bb,"Redefinir",32,628,120,50,"nickclear")
 self:button(bb,"Acentos",164,628,130,50,"accents")
 self:button(bb,"Salvar nome",306,628,262,50,"nicksave")
 self:button(bb,"Voltar ao perfil",32,717,536,44,"nav","profile")
end
function View:loadBackups()
 self.backup_info={};self.backup_errors={}
 for _,slot in ipairs({"backup","before-restore"}) do
  if self.owner.backups then self.backup_info[slot],self.backup_errors[slot]=self.owner.backups:preview(slot)
  else self.backup_errors[slot]="Backups indisponíveis." end
 end
end
function View:paintBackups(bb)
 self:title(bb,"Guarde seu progresso","Jogo e registros de leitura salvos juntos.")
 if self.owner.backups and self.owner.backups.blocked then
  self:wrapped(bb,"A restauração foi interrompida. Feche e reabra o SanrioKindle para concluir.",310,22)
  self:button(bb,"Fechar SanrioKindle",32,595,536,55,"exit");return
 end
 if not self.backup_info then self:loadBackups() end
 self:button(bb,"Salvar backup agora",32,194,536,52,"makebackup",nil,nil,not self.owner.backups)
 for i,slot in ipairs({"backup","before-restore"}) do
  local b=self.backup_info[slot];local y=283+(i-1)*164
  self:text(bb,i==1 and "Backup salvo" or "Antes da restauração",32,y,23,536,true)
  self:text(bb,b and savedDate(b.at)..(b.previous and " / cópia anterior" or "") or self.backup_errors[slot],32,y+35,17,536)
  self:button(bb,"Prévia",32,y+74,536,46,"previewbackup",slot,nil,not b)
 end
 self:wrapped(bb,self.backup_message or "Confira o backup antes de restaurar. Seu jogo atual é guardado para poder voltar.",632,18)
 self:backButton(bb)
end
function View:paintRestore(bb)
 local b=self.restore_preview
 if not b then self:paintBackups(bb);return end
 local s=b.state
 self:title(bb,"Restaurar este backup?",savedDate(b.at))
 self:text(bb,self.engine.displayName(s).." / Nv. "..self.engine.level(s),32,202,26,536,true,true)
 if s.species~=0 then self:sprite(bb,s.species,204,252,192,1) end
 self:text(bb,s.berries.." frutas / "..self.engine.count(s.seen).." amigos conhecidos",32,465,20,536,false,true)
 self:text(bb,math.floor((s.reading and s.reading.seconds or 0)/60).." minutos lidos",32,504,20,536,false,true)
 self:wrapped(bb,"Seu jogo atual ficará em Antes da restauração.",553,18)
 self:button(bb,"Restaurar este backup",32,618,536,55,"restorebackup")
 self:button(bb,"Cancelar",32,717,536,44,"nav","backups")
end
function View:paintBadges(bb)
 self:title(bb,"Conquistas",self.engine.count(self.state.badges).." de "..#self.engine.badge_goals.." insígnias conquistadas")
 local pages=math.ceil(#self.engine.badge_goals/6);self.page=math.min(self.page or 1,pages)
 for i=(self.page-1)*6+1,math.min(self.page*6,#self.engine.badge_goals) do
  local b=self.engine.badge_goals[i];local y=185+(i-1)%6*73;local earned=self.state.badges[b[1]];self.art.icon(self,bb,"badge",39,y+6,3,earned and BLACK or GRAY)
  self:text(bb,self.engine.labels.get(b[1])..(earned and " - conquistada" or ""),91,y,20,469,earned);self:text(bb,b[2],91,y+33,16,469);self:rect(bb,91,y+66,477,1,LIGHT)
 end
 self:button(bb,"Anterior",32,652,262,44,"extrapage",-1,nil,self.page==1)
 self:button(bb,"Próximo",306,652,262,44,"extrapage",1,nil,self.page==pages)
 self:backButton(bb)
end
function View:startPlay()
 self.engine.advance(self.state,os.time());local allowed,why=self.engine.canPlay(self.state,os.time())
 if not allowed then self.message=why;self:go("home");return end
 self:go("play");self.play_phase="show";self.play_pos=1;self.play_sequence={}
 local seed=(os.time()+self.state.seed)%2147483647
 for i=1,3 do seed=(seed*48271)%2147483647;self.play_sequence[i]=seed%3+1 end
end
function View:paintPlay(bb)
 self:title(bb,"Trilha de frutas","Memorize o caminho e ajude seu amigo a segui-lo.");self:sprite(bb,self.state.species,204,198,192,1)
 if self.play_phase=="show" then
  self:text(bb,"Memorize a ordem dos arbustos:",32,420,20,536,false,true);self.art.text(self,bb,table.concat(self.play_sequence," - "),192,473,4)
  self:button(bb,"Pronto! Esconder o caminho",32,556,536,55,"hidepath",nil,"berry")
 else
  self:text(bb,"Escolha o arbusto "..self.play_pos.." de 3",32,420,22,536,true,true)
  for i=1,3 do self:button(bb,"Arbusto "..i,32+(i-1)*182,494,172,79,"pickbush",i,"berry") end
  self:text(bb,"Uma trilha perfeita rende mais 3 XP.",32,620,17,536,false,true)
 end
 self:backButton(bb)
end
function View:pickBush(i)
 if self.play_phase~="pick" then return end
 if i~=self.play_sequence[self.play_pos] then self.play_phase="done";self:act("play","try");return end
 self.play_pos=self.play_pos+1
 if self.play_pos>3 then self.play_phase="done";self:act("play","perfect") else UIManager:setDirty(self,"ui") end
end
function View:paintTrain(bb)
 self:title(bb,"Um pouco de treino","18 energia / 8 comida / +12 XP / +2 vínculo");local lv=self.engine.level(self.state)
 for i,m in ipairs(self.engine.moves(self.state)) do
  local y=200+(i-1)*112;local locked=lv<m.level
  self:button(bb,m.name,32,y,536,56,"train",m.name,"ball",locked)
  self:text(bb,locked and "Disponível no Nv. "..m.level or "Pronto para praticar com seu parceiro",43,y+71,17,513)
 end
 self:backButton(bb)
end
function View:paintMore(bb)
 self:title(bb,"Ao redor do ninho","Pequenos confortos para seu parceiro.")
 self:button(bb,"Preferências",32,191,262,50,"nav","preferences")
 self:button(bb,"Livros juntos",306,191,262,50,"nav","memories")
 self:button(bb,"Cenários",32,263,262,50,"nav","backgrounds")
 self:button(bb,"Decorações",306,263,262,50,"nav","decorations")
 self:text(bb,"Animação",32,339,20,536,true)
 for i,b in ipairs({{"Suave","gentle"},{"Eco","eco"},{"Não","off"}}) do self:button(bb,b[1],32+(i-1)*182,375,172,48,"animation",b[2],nil,false,self.state.animation==b[2]) end
 self:text(bb,"Suave: até 4 quadros. Eco: 2. Não: parada.",32,440,17,536)
 self:button(bb,"Atualizar tela - limpar rastros",32,488,536,48,"refresh",nil,"clean")
 self:button(bb,"Guia de cuidados",32,558,262,48,"nav","help","book")
 self:button(bb,"Frutas favoritas",306,558,262,48,"nav","snacks","berry")
 self:button(bb,"Recompensas de leitura",32,628,262,48,"nav","reading","book")
 self:button(bb,"Backups",306,628,262,48,"nav","backups")
 self:backButton(bb)
end
function View:paintReading(bb)
 local r=self.state.reading or {enabled=true,seconds=0,carry=0}
 self:title(bb,"Leitura","Continue lendo seu livro.")
 self:button(bb,"Conferir de novo",398,97,170,40,"rescan")
 self:text(bb,math.floor(r.seconds/60).." minutos lidos",32,211,28,536,true,true)
 self:progress(bb,62,267,476,r.carry%900,900)
 self:text(bb,math.ceil((900-r.carry%900)/60).." min até a próxima recompensa",32,304,20,536,false,true)
 self:text(bb,"15 minutos = 1 fruta + 3 XP",32,347,17,536,false,true)
 self:button(bb,"Expedições",32,411,262,54,"nav","explore","boot")
 self:button(bb,self.state.egg and self.engine.eggLeft(self.state)==0 and "Abrir presente" or "Seu presente",306,411,262,54,"nav","egg")
 self:button(bb,"Meta semanal",32,487,262,54,"nav","weekly")
 self:button(bb,"Última visita",306,487,262,54,"nav","recap",nil,not self.owner.recap)
 self:button(bb,r.enabled and "Recompensas: Sim" or "Recompensas: Não",32,570,262,48,"reading",nil,"book",false,r.enabled)
 self:button(bb,"Histórico de leitura",306,570,262,48,"nav","readinghistory")
 local status=self.owner.reading_status or {"Kindle: conferido ao abrir o SanrioKindle","KOReader: registra enquanto você lê"}
 for i,line in ipairs(status) do self:text(bb,line,32,643+(i-1)*30,16,536) end
 self:backButton(bb)
end
function View:paintHelp(bb)
 self:title(bb,"Guia de cuidados","Duas ou três visitas rápidas por dia bastam.")
 local help={{"Alimentar","Uma fruta repõe 24 de comida. A cesta enche todo dia."},{"Brincar","Siga 3 arbustos em ordem. Disponível a cada 30 minutos."},
  {"Praticar","Treine um golpe por hora para ganhar XP e vínculo."},{"Descansar e limpar","Descanse para repor energia. Limpe o ninho."},
  {"Ler e explorar","Ler avança passeios e prepara presentes."},{"Crescer juntos","Cada 20 XP dá um nível de amizade."}}
 for i,h in ipairs(help) do local y=190+(i-1)*78;self:text(bb,h[1],32,y,20,536,true);self:text(bb,h[2],32,y+31,16,536) end
 self:backButton(bb)
end
function View:onTap(_,ges)
 if self.closed or self.suspended then return true end
 local x=(ges.pos.x-self.ox)/self.scale;local y=(ges.pos.y-self.oy)/self.scale
 for _,b in ipairs(self.buttons) do if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then
  if b.action=="exit" then self:leave()
  elseif self.owner.backups and self.owner.backups.blocked then return true
  elseif self.owner.reading_busy and b.action~="nav" and b.action~="page" then return true
  elseif b.disabled then return true
  elseif self:companionTap(b.action,b.arg) then return true
  elseif b.action=="starter" then
   self.starter_index=(self.starter_index-1+b.arg)%#self.engine.starters+1
   self:freeImages();UIManager:setDirty(self,"ui")
  elseif b.action=="nav" then
   self:go(b.arg);if b.arg=="home" then self.message=self.engine.act(self.state,"check",nil,os.time()) end
  elseif b.action=="entry" then
   self.entry_from=self.screen
   self:go("entry");self.detail_id=b.arg;self.preview_pose="idle"
  elseif b.action=="preview" then self.preview_pose=b.arg;self:animate("preview");UIManager:setDirty(self,"ui")
  elseif b.action=="hello" then self.message=self.engine.act(self.state,"check",nil,os.time());self:animate("hello");UIManager:setDirty(self,"ui")
  elseif b.action=="startplay" then self:startPlay()
  elseif b.action=="hidepath" then self.play_phase="pick";UIManager:setDirty(self,"ui")
  elseif b.action=="pickbush" then self:pickBush(b.arg)
  elseif b.action=="refresh" then self:stopAnimation();UIManager:setDirty(self,"full")
  elseif b.action=="tripmode" then self.trip_mode=b.arg;UIManager:setDirty(self,"ui")
  elseif b.action=="decorate" then
   self.decor_message=self.engine.act(self.state,"decorate",b.arg,os.time());self.owner:save();UIManager:setDirty(self,"ui")
  elseif b.action=="nickkey" then
   if #(self.engine.companion.text.chars(self.nickname_text) or {})<12 then self.nickname_text=self.nickname_text..b.arg end;UIManager:setDirty(self,"ui")
  elseif b.action=="nickcase" then self.uppercase=not self.uppercase;UIManager:setDirty(self,"ui")
  elseif b.action=="nickdelete" then self.nickname_text=self.engine.companion.text.pop(self.nickname_text);UIManager:setDirty(self,"ui")
  elseif b.action=="nickclear" then self.nickname_text="";UIManager:setDirty(self,"ui")
  elseif b.action=="nicksave" then
   self.message=self.engine.act(self.state,"nickname",self.nickname_text,os.time());self.owner:save();self:go("profile")
  elseif b.action=="makebackup" then
   local ok,err=self.owner.backups:create(self.state)
   if ok then self.owner.save_error=nil end
   self.backup_message=ok and "Backup salvo." or tostring(err or "Não foi possível salvar o backup.")
   self:loadBackups();UIManager:setDirty(self,"ui")
  elseif b.action=="previewbackup" then
   self.restore_preview=self.backup_info[b.arg];self:go("restore")
  elseif b.action=="restorebackup" then
   local ok,err=self.owner.backups:restore(self.state,self.restore_preview)
   if ok then
    self.owner.save_error=nil;self.owner.recap=nil;self.restore_preview=nil;self.message="Backup restaurado. Seu jogo anterior foi preservado.";self:go("home")
   else self.backup_message=tostring(err or "Não foi possível restaurar o backup.");self:go("backups") end
  elseif b.action=="page" then
   local count=self.screen=="history" and #self.state.log or (self.journal_count or self.engine.count(self.state.seen))
   self:freeImages();self.page=math.max(1,math.min(math.max(1,math.ceil(count/6)),self.page+b.arg));UIManager:setDirty(self,"ui")
  elseif b.action=="animation" or b.action=="background" or b.action=="goal" then self.engine.act(self.state,b.action,b.arg,os.time());self.owner:save();UIManager:setDirty(self,"ui")
  elseif b.action=="reading" then
   if self.owner.toggleReading then self.owner:toggleReading() end
   UIManager:setDirty(self,"ui")
  else self:act(b.action,b.arg) end
  return true
 end end
 return true
end
function View:onSwipe() return true end
function View:onBack()
 if self.screen=="home" or (self.owner.backups and self.owner.backups.blocked) then self:leave()
 elseif self.screen=="companions" then self:go("profile")
 elseif self.screen=="allcompanions" then self:go(self.state.species==0 and "home" or "companions")
 elseif self.screen=="entry" and self.entry_from and self.entry_from~="journal" then self:go(self.entry_from)
 else self:go("home") end
 return true
end
function View:onClose() self:leave();return true end
function View:leave()
 if self.closed then return end
 self:stopAnimation();self.closed=true;local ok=self.owner:save();UIManager:close(self,"full")
 if not ok then UIManager:show(require("ui/widget/infomessage"):new{text=self.owner.backups and self.owner.backups.blocked
  and "Reabra o SanrioKindle para concluir a restauração do backup." or "O SanrioKindle não conseguiu salvar. Confira o espaço livre antes de jogar novamente."}) end
end
function View:onCloseWidget()
 self:stopAnimation();self.closed=true;self:freeImages();self.owner.pet_view=nil
 if self.owner.onPetClosed then self.owner:onPetClosed() end
end
function View:onSuspend()
 if self.suspended or self.closed then return end;self.suspended=true;self:stopAnimation();self.engine.companion.suspend(self.state,self.engine,os.time());self.owner:save()
end
function View:onResume()
 if not self.suspended or self.closed then return end
 self.engine.companion.resume(self.state,self.engine,os.time());self.owner:save()
 self.suspended=false;self:freeImages();self:geometry();self.message=self.engine.act(self.state,"check",nil,os.time());UIManager:setDirty(self,"full")
end
function View:onSetDimensions() self:stopAnimation();self:freeImages();self:geometry();UIManager:setDirty(self,"full");return true end
dofile(debug.getinfo(1,"S").source:sub(2):match("^(.*)/").."/companion_view.lua")(View,UIManager,BB)
return View
