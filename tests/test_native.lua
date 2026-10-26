app.owner:syncReading()
local s=app.state;local E=app.engine;local v=app.view
assert(app.owner.pet_view==v)
app.owner:startReadingScan();assert(app.owner.scan_step)
app.owner.scan_step();assert(not app.owner.reading_busy)
for key in pairs(s) do s[key]=nil end
for key,value in pairs(E.new(os.time())) do s[key]=value end
local function tap(action,arg)
 app_paint()
 for _,button in ipairs(v.buttons) do
  if button.action==action and button.arg==arg then
   assert(not button.disabled);local r=v:region(button.x+4,button.y+4,0,0)
   v:onTap(nil,{pos={x=r.x,y=r.y}});return
  end
 end
 error('Missing native control: '..action)
end
tap('nav','allcompanions');app_paint();assert(v.journal_count==4)
tap('entry',3);tap('choose',3);assert(s.species==3)
v:go('profile');tap('nav','companions');tap('nav','allcompanions')
tap('entry',4);tap('partner',4);assert(s.species==4)
v:go('home');s.animation='off';s.food=60;s.berries=6
v:act('feed');assert(s.food==84 and s.berries==5)
s.seen['2']=true;v:act('partner',2);assert(s.species==2 and s.xp==0)
s.xp=60;s.bond=30;v:act('partner',4);v:act('partner',2);assert(s.xp==60 and s.bond==30)
v:go('entry');v.detail_id=2
for _,pose in ipairs({'idle','sleep','walk','attack','eat'}) do
 v.preview_pose=pose
 for frame=1,v.poses[2][pose] do v.frame=frame;app_paint();assert(#v.buttons==9) end
end
assert(app.owner:save())
local save=app.storage.save;app.storage.save=function() return nil,'Test save failure' end
assert(not app.owner:save() and app.owner.save_error)
v:go('more');app_paint();v:go('home');app_paint()
app.storage.save=save;assert(app.owner:save() and not app.owner.save_error)
local loaded=app.storage.load('data/sanriokindle.dat',E);assert(loaded.species==2 and loaded.partners['4'])
v:onSuspend();assert(#app.ui.queue==0);v:onResume()
print('NATIVE: drawing, actions, partner progress, save reload and suspend passed')

for id=1,4 do
 v:act('partner',id);v:go('home');app_paint()
 for _,pose in ipairs({'idle','sleep','walk','attack','eat'}) do
  for frame=1,v.poses[id][pose] do v:sprite(nil,id,204,200,192,frame,pose) end
 end
end
local R=dofile('game/reading.lua');R.init(s);s.berries=20
v:act('egg');assert(s.egg);E.readingReward(s,7200,os.time());v:act('hatch');assert(not s.egg)
v:go('sleeppreview');app_paint();v:go('home');app_paint()
assert(app.owner:save())
print('SANRIO NATIVO: quatro amigos, 72 quadros, presentes e telas verificados')
