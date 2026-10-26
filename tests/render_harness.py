import sys,pathlib,os,tempfile,json,io,time,datetime
from lupa.luajit21 import LuaRuntime
from PIL import Image,ImageDraw,ImageFont
REPO=pathlib.Path(__file__).resolve().parents[1]
ROOT=REPO/'sanriokindle.koplugin'
OUT=REPO/'tests'/'rendered';OUT.mkdir(exist_ok=True)
lua=LuaRuntime(unpack_returned_tuples=True)
g=lua.globals();g.BASE=ROOT.as_posix()
temp=tempfile.TemporaryDirectory();g.TESTDIR=pathlib.Path(temp.name).resolve().as_posix()
# Windows CRT rename does not replace files; emulate the Kindle's POSIX rename.
def rename(a,b):
 try:os.replace(a,b);return True
 except OSError as ex:return None,str(ex)
g.host_rename=rename;lua.execute('os.rename=host_rename')
def fs(op,path):
 p=pathlib.Path(path)
 if op=='pid':return os.getpid()
 if op=='mode':
  if path==f'/proc/{os.getpid()}':return 'directory'
  return 'link' if p.is_symlink() else 'directory' if p.is_dir() else 'file' if p.is_file() else None
 if op=='mtime':return p.stat().st_mtime if p.exists() else None
 try:
  if op=='mkdir':p.mkdir()
  elif op=='rmdir':p.rmdir()
  else:return False
  return True
 except OSError:return False
def listdir(path):
 try:return lua.table_from(os.listdir(path))
 except OSError:return None
g.host_fs=fs;g.host_listdir=listdir

sprite_index=json.loads((ROOT/'assets/sprite-index.json').read_text(encoding="utf-8"))
def read_sprite(name):
 species,offset,length=sprite_index[name]
 with (ROOT/'assets'/f'{species:03d}.bin').open('rb') as stream:
  stream.seek(offset);data=stream.read(length)
 assert len(data)==length
 return Image.open(io.BytesIO(data))

canvas=None;draw=None;bounds=[];truncated=[];painted_text=[];painted_sprites=[];painted_text_boxes=[]
def font(size,bold=False):
 bundled=REPO/'native/fonts'/('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf')
 if bundled.is_file():return ImageFont.truetype(str(bundled),int(size))
 choices=(['C:/Windows/Fonts/arialbd.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'] if bold
          else ['C:/Windows/Fonts/arial.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'])
 if os.environ.get('POKEPAL_TEST_FONT_DIR'):
  path=pathlib.Path(os.environ['POKEPAL_TEST_FONT_DIR'])/('NotoSans-Bold.ttf' if bold else 'NotoSans-Regular.ttf')
  assert path.is_file(),f'Missing test font: {path}'
  choices.insert(0,str(path))
 for path in choices:
  if pathlib.Path(path).is_file():return ImageFont.truetype(path,int(size))
 return ImageFont.load_default(size=int(size))
def get_text(t,sz,bold,maxw):
 f=font(sz,bold);original=t
 maxw=maxw or 100000
 while draw.textlength(t,font=f)>maxw and t:
  t=t[:-1]
 if t!=original:
  truncated.append(original);t=t[:-2]+'...'
 return t,f
def text_size(t,sz,bold,maxw):
 t,f=get_text(t,sz,bold,maxw);return round(draw.textlength(t,font=f)),sum(f.getmetrics())
def render_text(t,x,y,sz,bold,maxw):
 painted_text.append(t)
 t,f=get_text(t,sz,bold,maxw)
 painted_text_boxes.append((t,x,y,round(draw.textlength(t,font=f)),sum(f.getmetrics()),sz))
 draw.text((round(x),round(y)),t,font=f,fill=0,anchor='la')
def rect(x,y,w,h,col):
 x,y,w,h=map(round,(x,y,w,h))
 if w and h:
  if x<0 or y<0 or x+w>canvas.width or y+h>canvas.height:bounds.append((x,y,w,h))
  draw.rectangle((x,y,x+w-1,y+h-1),fill=int(col))
def image(path,x,y,w,h):
 painted_sprites.append(int(pathlib.Path(path).name.split('-')[0]))
 img=read_sprite(pathlib.Path(path).name).convert('LA').resize((int(w),int(h)),Image.Resampling.NEAREST)
 canvas.paste(img.getchannel('L'),(round(x),round(y)),img.getchannel('A'))
g.text_size=text_size;g.render_text=render_text;g.render_rect=rect;g.render_image=image
lua.execute(r'''
local W={}
function W:extend(o) o=o or {};setmetatable(o,self);self.__index=self;return o end
function W:new(o) o=self:extend(o);if o._init then o:_init() end;if o.init then o:init() end;return o end
local Input=W:extend{}
function Input:_init() self.key_events={};self.ges_events={} end
package.preload["ui/widget/container/inputcontainer"]=function() return Input end
package.preload["ui/widget/container/widgetcontainer"]=function() return W end
package.preload["ui/geometry"]=function() return W end
package.preload["ui/gesturerange"]=function() return W end
package.preload["ui/font"]=function()
 return {getFace=function(_,name,size) return {size=require('device').screen:scaleBySize(size)} end}
end
local T=W:extend{}
function T:getSize() local w,h=text_size(self.text,self.face.size,self.bold,self.max_width);return {w=w,h=h} end
function T:paintTo(bb,x,y) render_text(self.text,x,y,self.face.size,self.bold,self.max_width) end
function T:free() end
package.preload["ui/widget/textwidget"]=function() return T end
local I=W:extend{}
function I:paintTo(bb,x,y) assert(not self.freed);render_image(self.file or self.image.file,x,y,self.width,self.height) end
function I:free() self.freed=true end
package.preload["ui/widget/imagewidget"]=function() return I end
package.preload["ui/renderimage"]=function()
 local R={}
 local packed=dofile(BASE..'/assets/sprites.lua');local names={}
 for name in pairs(packed.index) do names[packed.read(BASE..'/assets',name)]=BASE..'/assets/'..name end
 function R:renderImageData(data)
  local file=assert(names[data]);local raw={file=file,getWidth=function() return 96 end,getHeight=function() return 96 end,scale=function(self,w,h) return {file=self.file,free=function() end} end,free=function() end}
  return raw
 end
 return R
end
package.preload["ffi/blitbuffer"]=function() return {COLOR_WHITE=255,COLOR_BLACK=0,Color8=function(n) return n end} end
D={w=600,h=800}
package.preload["device"]=function()
 local screen={getWidth=function() return D.w end,getHeight=function() return D.h end}
 -- KOReader's Font:getFace calls this, including the user's DPI override.
 -- koreader-base/ffi/framebuffer.lua, scaleBySize (3244ca3f7c36).
 function screen:scaleBySize(px)
  local scale=math.min(self:getWidth(),self:getHeight())/600
  return math.ceil(px*(scale+(D.dpi and D.dpi/160 or scale))/2)
 end
 return {screen_saver_mode=false,screen=screen}
end
U={queue={},dirty={},show_count=0}
function U:scheduleIn(seconds,f) self.queue[#self.queue+1]={seconds=seconds,f=f} end
function U:unschedule(f) for i=#self.queue,1,-1 do if self.queue[i].f==f then table.remove(self.queue,i) end end end
function U:setDirty(widget,mode,region) self.dirty[#self.dirty+1]={mode=mode,region=region} end
function U:show(v) self.show_count=self.show_count+1 end
function U:close(v) v:onCloseWidget() end
function U:drain() local n=0;while #self.queue>0 do n=n+1;assert(n<=10,'unbounded animation');local t=table.remove(self.queue,1);t.f() end;return n end
package.preload["ui/uimanager"]=function() return U end
package.preload["datastorage"]=function() return {getSettingsDir=function() return TESTDIR end} end
package.preload["ffi/util"]=function() return {} end
package.preload["ui/widget/infomessage"]=function() return W end
bb={paintRect=function(_,...) render_rect(...) end}
E=dofile(BASE.."/engine.lua");V=dofile(BASE.."/view.lua")
Device=require("device")
function newView(id)
 local s=E.new(os.time());if id then E.act(s,'choose',id,os.time()) end
 local owner={save=function(self) self.saved=(self.saved or 0)+1;return true end}
 local v=V:new{engine=E,state=s,owner=owner,path=BASE};owner.pet_view=v;return v
end
function tapButton(view,action,arg)
 view:paintTo(bb,0,0)
 for _,button in ipairs(view.buttons) do
  if button.action==action and button.arg==arg then
   local r=view:region(button.x+4,button.y+4,0,0)
   view:onTap(nil,{pos={x=r.x,y=r.y}});return button
  end
 end
 error('Button not found: '..action..' '..tostring(arg))
end
''')
def start(w=600,h=800):
 global canvas,draw,bounds,truncated,painted_text,painted_sprites,painted_text_boxes
 canvas=Image.new('L',(w,h),255);draw=ImageDraw.Draw(canvas);bounds=[];truncated=[];painted_text=[];painted_sprites=[];painted_text_boxes=[]
 g.D.w=w;g.D.h=h
